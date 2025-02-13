// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CongressDAO {
    // Enums
    enum VoteDecision { Nay, Yea, Abstain }
    enum MemberType { House, Senate, VP, Non_Voting, Prez }

    // Custom Errors
    error NotOwner();
    error AlreadyMember();
    error HouseFull();
    error HouseDistrictRequired();
    error SenateFull();
    error SenateDistrictMustBeZero();
    error VPActive();
    error PresidentActive();
    error InvalidAddress();
    error NotActiveMember();
    error SponsorRequired();
    error SectionRequired();
    error EffectiveDatePast();
    error InvalidSponsor();
    error InvalidCosponsor();
    error InvalidBillIndex();
    error NotCurrentVP();
    error NoTieBreakRequired();
    error OnlyPresident();
    error VotingClosed();
    error OnlyHouse();
    error AlreadyVoted();
    error OnlySenate();
    error AlreadyNominated();

    // Structs with optimized storage types
    struct Member {
        bytes32 fName;       // Fixed-length first name
        bytes32 lName;       // Fixed-length last name
        MemberType memberType;
        uint40 termStart;    // Packed timestamp (seconds)
        uint24 termDuration; // Duration in seconds (e.g., 730 days for House)
        uint40 termEnd;      // Calculated as termStart + termDuration
        bytes2 state;        // Two-letter state abbreviation (e.g., "CA")
        uint16 district;
    }

    struct VoteCounts {
        uint16 yea;
        uint16 nay;
        uint16 abs;
    }

    struct BillMetadata {
        string title;
        string enactingClause;
        uint proposedDate;
        uint effectiveDate;
    }

    struct BillSponsorship {
        address[] sponsors;
        address[] cosponsors;
    }

    // Note: Instead of using dynamic arrays for vote tracking, we use counters.
    struct BillVoting {
        bool passedHouse;
        bool passedSenate;
        bool passed;
        bool tieBreakRequired;
        bool votingAllowed;
        VoteCounts houseVotes;
        VoteCounts senateVotes;
        uint16 houseVoteCount;  // Tracks total House votes cast
        uint16 senateVoteCount; // Tracks total Senate votes cast
        VoteDecision presidentVote;
        bool presidentVoted;
    }

    struct Bill {
        BillMetadata metadata;
        BillSponsorship sponsorship;
        BillVoting voting;
        string[] sections;
        string[] definitions;
    }

    // The Nomination struct now uses a mapping to track ratifiers.
    struct Nomination {
        address candidate;
        bytes32 fName;
        bytes32 lName;
        MemberType memberType;
        bytes2 state;
        uint16 district;
        uint40 nominationTimestamp;
        uint16 ratificationCount;
        // Mapping for quick lookup if an address has already ratified.
        mapping(address => bool) ratifiers;
        bool ratified;
    }

    // Constants for term durations
    uint32 private constant TWO_YEARS = 730 days;
    uint32 private constant SIX_YEARS = 2190 days;
    uint32 private constant FOUR_YEARS = 1460 days;


    // Limits and state variables
    uint public maxHouse = 435;
    uint public maxSenate = 100;

    Bill[] public billHistory;
    address[] public houseMembers;
    address[] public senateMembers;

    // Mappings for membership and vote tracking
    mapping(address => Member) public members;
    mapping(address => bool) public isHouseMember;
    mapping(address => bool) public isSenateMember;
    uint16 public houseMemberCount;
    uint16 public senateMemberCount;

    // Mapping for vote tracking (per bill index)
    mapping(uint256 => mapping(address => bool)) public hasVotedHouse;
    mapping(uint256 => mapping(address => bool)) public hasVotedSenate;

    // Leadership roles
    address public vpMember;
    address public president;
    address public owner;

    // Mapping of candidate address to their nomination details.
    mapping(address => Nomination) public nominations;

    constructor() {
        owner = msg.sender;
    }

    // Modifier to restrict functions to the contract owner.
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // Internal function to register a new member using optimized types.
    function _registerMember(
        address member,
        bytes32 fName,
        bytes32 lName,
        MemberType memberType,
        bytes2 state,
        uint16 district
    ) internal {
        // Use termEnd as a flag: if nonzero, the member is already registered.
        if (members[member].termEnd != 0) revert AlreadyMember();

        uint32 termDuration;
        if (memberType == MemberType.House || memberType == MemberType.Non_Voting) {
            termDuration = TWO_YEARS;
            isHouseMember[member] = true;
            houseMemberCount++;
            houseMembers.push(member);
        } else if (memberType == MemberType.Senate) {
            termDuration = SIX_YEARS;
            isSenateMember[member] = true;
            senateMemberCount++;
            senateMembers.push(member);
        } else {
            termDuration = FOUR_YEARS;
        }

        members[member] = Member({
            fName: fName,
            lName: lName,
            memberType: memberType,
            termStart: uint40(block.timestamp),
            termDuration: termDuration,
            termEnd: uint40(block.timestamp + termDuration),
            state: state,
            district: district
        });
    }

    // Owner-only function to add a member directly.
    function addMember(
        address member,
        bytes32 fName,
        bytes32 lName,
        MemberType memberType,
        bytes2 state,
        uint16 district
    ) public onlyOwner {
        // Additional checks similar to your original logic can be added here.
        _registerMember(member, fName, lName, memberType, state, district);
    }

    // Returns the number of bills in history.
    function getBillHistoryLength() public view returns (uint256) {
        return billHistory.length;
    }

    // Returns metadata for a specific bill.
    function getBillMetadata(uint256 billIndex) public view returns (BillMetadata memory) {
        require(billIndex < billHistory.length, "Invalid bill index");
        return billHistory[billIndex].metadata;
    }

    // Propose a new bill.
    function proposeBill(
        string memory title,
        string memory enactingClause,
        string[] memory sections,
        string[] memory definitions,
        uint effectiveDate,
        address[] memory sponsors,
        address[] memory cosponsors
    ) public {
        // Ensure the proposer is an active member.
        if (members[msg.sender].termEnd <= block.timestamp) revert NotActiveMember();
        if (sponsors.length == 0) revert SponsorRequired();
        if (sections.length == 0) revert SectionRequired();
        if (effectiveDate < block.timestamp) revert EffectiveDatePast();

        // Validate sponsors and cosponsors.
        for (uint i = 0; i < sponsors.length; ) {
            if (members[sponsors[i]].termEnd <= block.timestamp) revert InvalidSponsor();
            unchecked { i++; }
        }
        for (uint i = 0; i < cosponsors.length; ) {
            if (members[cosponsors[i]].termEnd <= block.timestamp) revert InvalidCosponsor();
            unchecked { i++; }
        }

        BillMetadata memory metadata = BillMetadata({
            title: title,
            enactingClause: enactingClause,
            proposedDate: block.timestamp,
            effectiveDate: effectiveDate
        });

        BillSponsorship memory sponsorship = BillSponsorship({
            sponsors: sponsors,
            cosponsors: cosponsors
        });

        BillVoting memory voting = BillVoting({
            passedHouse: false,
            passedSenate: false,
            passed: false,
            tieBreakRequired: false,
            votingAllowed: true,
            houseVotes: VoteCounts(0, 0, 0),
            senateVotes: VoteCounts(0, 0, 0),
            houseVoteCount: 0,
            senateVoteCount: 0,
            presidentVote: VoteDecision.Abstain,
            presidentVoted: false
        });

        billHistory.push(Bill({
            metadata: metadata,
            sponsorship: sponsorship,
            voting: voting,
            sections: sections,
            definitions: definitions
        }));
    }

    // Cast a vote on a bill.
    function castVote(uint256 billIndex, VoteDecision decision) public {
        if (members[msg.sender].termEnd <= block.timestamp) revert NotActiveMember();
        if (billIndex >= billHistory.length) revert InvalidBillIndex();

        Bill storage bill = billHistory[billIndex];
        Member storage member = members[msg.sender];

        // Handle tie-break votes from the VP.
        if (member.memberType == MemberType.VP) {
            if (msg.sender != vpMember) revert NotCurrentVP();
            if (!bill.voting.tieBreakRequired) revert NoTieBreakRequired();
            processTieBreakVote(bill, decision);
            return;
        }

        // Handle the president's vote if required.
        if (bill.voting.passedHouse && bill.voting.passedSenate && !bill.voting.presidentVoted) {
            if (msg.sender != president) revert OnlyPresident();
            processPresidentVote(bill, decision);
            return;
        }

        if (!bill.voting.votingAllowed) revert VotingClosed();

        // Voting in the House chamber.
        if (!bill.voting.passedHouse) {
            if (member.memberType != MemberType.House) revert OnlyHouse();
            if (hasVotedHouse[billIndex][msg.sender]) revert AlreadyVoted();

            unchecked {
                if (decision == VoteDecision.Yea) {
                    bill.voting.houseVotes.yea++;
                } else if (decision == VoteDecision.Nay) {
                    bill.voting.houseVotes.nay++;
                } else {
                    bill.voting.houseVotes.abs++;
                }
                bill.voting.houseVoteCount++;
            }
            hasVotedHouse[billIndex][msg.sender] = true;

            if (bill.voting.houseVoteCount == houseMemberCount) {
                bill.voting.passedHouse = (bill.voting.houseVotes.yea > bill.voting.houseVotes.nay);
            }
        }
        // Voting in the Senate chamber.
        else if (bill.voting.passedHouse && !bill.voting.passedSenate) {
            if (member.memberType != MemberType.Senate) revert OnlySenate();
            if (hasVotedSenate[billIndex][msg.sender]) revert AlreadyVoted();

            unchecked {
                if (decision == VoteDecision.Yea) {
                    bill.voting.senateVotes.yea++;
                } else if (decision == VoteDecision.Nay) {
                    bill.voting.senateVotes.nay++;
                } else {
                    bill.voting.senateVotes.abs++;
                }
                bill.voting.senateVoteCount++;
            }
            hasVotedSenate[billIndex][msg.sender] = true;

            if (bill.voting.senateVoteCount == senateMemberCount) {
                if (bill.voting.senateVotes.yea > bill.voting.senateVotes.nay) {
                    bill.voting.passedSenate = true;
                } else if (bill.voting.senateVotes.yea == bill.voting.senateVotes.nay) {
                    bill.voting.tieBreakRequired = true;
                }
            }
        } else {
            revert("Voting not allowed");
        }
    }

    // Internal function to process a tie-break vote from the VP.
    function processTieBreakVote(Bill storage bill, VoteDecision decision) internal {
        bill.voting.passedSenate = (decision == VoteDecision.Yea);
        bill.voting.tieBreakRequired = false;
    }

    // Internal function to process the president’s vote.
    function processPresidentVote(Bill storage bill, VoteDecision decision) internal {
        bill.voting.presidentVote = decision;
        bill.voting.presidentVoted = true;
        bill.voting.passed = (decision == VoteDecision.Yea);
        bill.voting.votingAllowed = false;
    }

    /**
     * @notice Allows an active member to nominate a candidate for membership.
     * Only nominations for House or Senate seats are permitted.
     */
    function nominateMember(
        address candidate,
        bytes32 fName,
        bytes32 lName,
        MemberType memberType,
        bytes2 state,
        uint16 district
    ) public {
        // Only active members may nominate.
        if (members[msg.sender].termEnd <= block.timestamp) revert NotActiveMember();
        // Limit nominations to House or Senate members.
        require(memberType == MemberType.House || memberType == MemberType.Senate, "Only House or Senate nominations allowed");
        if (candidate == address(0)) revert InvalidAddress();
        if (members[candidate].termEnd != 0) revert AlreadyMember();
        // Ensure the candidate is not already nominated.
        if (nominations[candidate].candidate != address(0)) revert AlreadyNominated();

        // Enforce similar district rules as in addMember.
        if (memberType == MemberType.House && district == 0) revert HouseDistrictRequired();
        if (memberType == MemberType.Senate && district != 0) revert SenateDistrictMustBeZero();

        // Since Nomination contains a mapping, we initialize it directly in storage.
        Nomination storage nomination = nominations[candidate];
        nomination.candidate = candidate;
        nomination.fName = fName;
        nomination.lName = lName;
        nomination.memberType = memberType;
        nomination.state = state;
        nomination.district = district;
        nomination.nominationTimestamp = uint40(block.timestamp);
        nomination.ratificationCount = 0;
        nomination.ratified = false;
    }

    /**
     * @notice Allows an active member to ratify a pending nomination.
     * Once ratifications exceed a threshold (half of the current chamber’s members),
     * the candidate is registered as a new member.
     */
    function ratifyMember(address candidate) public {
        if (members[msg.sender].termEnd <= block.timestamp) revert NotActiveMember();

        Nomination storage nomination = nominations[candidate];
        if (nomination.candidate == address(0)) revert("Nomination does not exist");
        if (nomination.ratifiers[msg.sender]) revert("Already ratified");

        nomination.ratifiers[msg.sender] = true;
        nomination.ratificationCount++;

        // Determine the threshold based on the candidate's chamber.
        uint threshold;
        if (nomination.memberType == MemberType.House) {
            threshold = houseMemberCount / 2;
        } else if (nomination.memberType == MemberType.Senate) {
            threshold = senateMemberCount / 2;
        }

        if (nomination.ratificationCount > threshold) {
            nomination.ratified = true;
            _registerMember(
                nomination.candidate,
                nomination.fName,
                nomination.lName,
                nomination.memberType,
                nomination.state,
                nomination.district
            );
            delete nominations[candidate];
        }
    }
}
