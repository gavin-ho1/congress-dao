// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CongressDAO {
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
    //Structs
    struct Member {
        string fName;
        string lName;
        MemberType memberType;
        uint termStart;
        uint termDuration;
        uint termEnd;
        string state;
        uint district;
    }

    struct VoteCounts {
        uint yea;
        uint nay;
        uint abs;
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

    struct BillVoting {
        bool passedHouse;
        bool passedSenate;
        bool passed;
        bool tieBreakRequired;
        bool votingAllowed;
        VoteCounts houseVotes;
        VoteCounts senateVotes;
        address[] houseMembersVoted;
        address[] senateMembersVoted;
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
    
    struct Nomination {
        address candidate;
        string fName;
        string lName;
        MemberType memberType;
        string state;
        uint district;
        uint nominationTimestamp;
        uint ratificationCount;
        address[] ratifiers;
        bool ratified;
    }

    uint maxHouse = 435;
    uint maxSenate = 100;
    Bill[] public billHistory;
    address[] public houseMembers;
    address[] public senateMembers;
    mapping(address => bool) public isMember;
    mapping(address => Member) public members;
    address public vpMember;
    address public president;
    address public owner;

    // Mapping of candidate address to their nomination details
    mapping(address => Nomination) public nominations;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // Internal helper to convert years to seconds
    function yearsToSeconds(uint256 _years) private pure returns (uint256) {
        return _years * 365 days;
    }
    
    // Internal function to register a new member.
    // This consolidates the logic so both the owner and a ratified nomination can add a member.
    function _registerMember(
        address member,
        string memory fName,
        string memory lName,
        MemberType memberType,
        string memory state,
        uint district
    ) internal {
        if (isMember[member]) revert AlreadyMember();
        
        if (memberType == MemberType.House) {
            if (houseMembers.length >= maxHouse) revert HouseFull();
            if (district == 0) revert HouseDistrictRequired();
        } else if (memberType == MemberType.Senate) {
            if (senateMembers.length >= maxSenate) revert SenateFull();
            if (district != 0) revert SenateDistrictMustBeZero();
        } else if (memberType == MemberType.VP) {
            if (vpMember != address(0) && members[vpMember].termEnd > block.timestamp) revert VPActive();
        } else if (memberType == MemberType.Prez) {
            if (president != address(0) && members[president].termEnd > block.timestamp) revert PresidentActive();
        }
    
        isMember[member] = true;
        uint termDuration;
        if (memberType == MemberType.House || memberType == MemberType.Non_Voting) {
            termDuration = yearsToSeconds(2);
        } else if (memberType == MemberType.Senate) {
            termDuration = yearsToSeconds(6);
        } else {
            termDuration = yearsToSeconds(4);
        }
        
        members[member] = Member({
            fName: fName,
            lName: lName,
            memberType: memberType,
            termStart: block.timestamp,
            termDuration: termDuration,
            termEnd: block.timestamp + termDuration,
            state: state,
            district: district
        });
    
        if (memberType == MemberType.House) {
            houseMembers.push(member);
        } else if (memberType == MemberType.Senate) {
            senateMembers.push(member);
        } else if (memberType == MemberType.VP) {
            vpMember = member;
        } else if (memberType == MemberType.Prez) {
            president = member;
        }
    }

    // Existing function for the owner to add a member directly.
    function addMember(
        address member,
        string memory fName,
        string memory lName,
        MemberType memberType,
        string memory state,
        uint district
    ) public onlyOwner {
        _registerMember(member, fName, lName, memberType, state, district);
    }

    function getBillHistoryLength() public view returns (uint256) {
        return billHistory.length;
    }
    function getBillMetadata(uint256 billIndex) public view returns (BillMetadata memory) {
        require(billIndex < billHistory.length, "Invalid bill index");
        return billHistory[billIndex].metadata;
    }

    function proposeBill(
        string memory title,
        string memory enactingClause,
        string[] memory sections,
        string[] memory definitions,
        uint effectiveDate,
        address[] memory sponsors,
        address[] memory cosponsors
    ) public {
        if (members[msg.sender].termEnd <= block.timestamp) revert NotActiveMember();
        if (sponsors.length == 0) revert SponsorRequired();
        if (sections.length == 0) revert SectionRequired();
        if (effectiveDate < block.timestamp) revert EffectiveDatePast();

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
            houseMembersVoted: new address[](0),
            senateMembersVoted: new address[](0),
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

    function castVote(uint256 billIndex, VoteDecision decision) public {
        if (members[msg.sender].termEnd <= block.timestamp) revert NotActiveMember();
        if (billIndex >= billHistory.length) revert InvalidBillIndex();

        Bill storage bill = billHistory[billIndex];

        if (members[msg.sender].memberType == MemberType.VP) {
            if (msg.sender != vpMember) revert NotCurrentVP();
            if (!bill.voting.tieBreakRequired) revert NoTieBreakRequired();
            processTieBreakVote(bill, decision);
            return;
        }

        if (bill.voting.passedHouse && bill.voting.passedSenate && !bill.voting.presidentVoted) {
            if (msg.sender != president) revert OnlyPresident();
            processPresidentVote(bill, decision);
            return;
        }

        if (!bill.voting.votingAllowed) revert VotingClosed();

        if (!bill.voting.passedHouse) {
            if (members[msg.sender].memberType != MemberType.House) revert OnlyHouse();
            if (isInArray(msg.sender, bill.voting.houseMembersVoted)) revert AlreadyVoted();
            
            if (decision == VoteDecision.Yea) bill.voting.houseVotes.yea++;
            else if (decision == VoteDecision.Nay) bill.voting.houseVotes.nay++;
            else bill.voting.houseVotes.abs++;
            
            bill.voting.houseMembersVoted.push(msg.sender);
            
            if (bill.voting.houseMembersVoted.length == houseMembers.length) {
                bill.voting.passedHouse = (bill.voting.houseVotes.yea > bill.voting.houseVotes.nay);
            }
        } else if (bill.voting.passedHouse && !bill.voting.passedSenate) {
            if (members[msg.sender].memberType != MemberType.Senate) revert OnlySenate();
            if (isInArray(msg.sender, bill.voting.senateMembersVoted)) revert AlreadyVoted();
            
            if (decision == VoteDecision.Yea) bill.voting.senateVotes.yea++;
            else if (decision == VoteDecision.Nay) bill.voting.senateVotes.nay++;
            else bill.voting.senateVotes.abs++;
            
            bill.voting.senateMembersVoted.push(msg.sender);
            
            if (bill.voting.senateMembersVoted.length == senateMembers.length) {
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

    function processTieBreakVote(Bill storage bill, VoteDecision decision) internal {
        bill.voting.passedSenate = (decision == VoteDecision.Yea);
        bill.voting.tieBreakRequired = false;
    }

    function processPresidentVote(Bill storage bill, VoteDecision decision) internal {
        bill.voting.presidentVote = decision;
        bill.voting.presidentVoted = true;
        bill.voting.passed = (decision == VoteDecision.Yea);
        bill.voting.votingAllowed = false;
    }

    function isInArray(address target, address[] storage arr) private view returns (bool) {
        for (uint i = 0; i < arr.length; ) {
            if (arr[i] == target) return true;
            unchecked { i++; }
        }
        return false;
    }
    /**
     * @notice Allows an active member to nominate a candidate for membership.
     * For simplicity, only nominations for House or Senate seats are allowed.
     */
    function nominateMember(
        address candidate,
        string memory fName,
        string memory lName,
        MemberType memberType,
        string memory state,
        uint district
    ) public {
        // Only active members may nominate
        if (members[msg.sender].termEnd <= block.timestamp) revert NotActiveMember();
        // Limit nominations to House or Senate members
        require(memberType == MemberType.House || memberType == MemberType.Senate, "Only House or Senate nominations allowed");
        if (candidate == address(0)) revert InvalidAddress();
        if (isMember[candidate]) revert AlreadyMember();
        // Ensure the candidate is not already nominated
        if (nominations[candidate].candidate != address(0)) revert AlreadyNominated();

        // Enforce similar district rules as in addMember
        if (memberType == MemberType.House && district == 0) revert HouseDistrictRequired();
        if (memberType == MemberType.Senate && district != 0) revert SenateDistrictMustBeZero();

        Nomination memory newNomination = Nomination({
            candidate: candidate,
            fName: fName,
            lName: lName,
            memberType: memberType,
            state: state,
            district: district,
            nominationTimestamp: block.timestamp,
            ratificationCount: 0,
            ratifiers: new address[](0),
            ratified: false
        });
        nominations[candidate] = newNomination;
    }

    /**
     * @notice Allows an active member to ratify a pending nomination.
     * Once ratifications exceed the majority of current members in the candidate's chamber,
     * the candidate is registered as a new member.
     */
    function ratifyMember(address candidate) public {
        // Only active members may ratify
        if (members[msg.sender].termEnd <= block.timestamp) revert NotActiveMember();

        Nomination storage nomination = nominations[candidate];
        if (nomination.candidate == address(0)) revert("Nomination does not exist");

        // Ensure the ratifier has not already ratified this nomination
        for (uint i = 0; i < nomination.ratifiers.length; i++) {
            if (nomination.ratifiers[i] == msg.sender) revert("Already ratified");
        }
        nomination.ratifiers.push(msg.sender);
        nomination.ratificationCount++;

        // Determine the threshold based on the candidate's chamber.
        uint threshold;
        if (nomination.memberType == MemberType.House) {
            threshold = houseMembers.length / 2;
        } else if (nomination.memberType == MemberType.Senate) {
            threshold = senateMembers.length / 2;
        }

        // If ratifications exceed the threshold, register the candidate as a member.
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
