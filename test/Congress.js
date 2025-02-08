const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CongressDAO", function () {
  let CongressDAO;
  let congressDAO;
  let owner, member1, member2, member3, vp, president, nonMember, nonMember2;

  // Helper function to get current EVM timestamp
  const currentTime = async () => {
    const block = await ethers.provider.getBlock("latest");
    return block.timestamp;
  };

  before(async function () {
    [owner, member1, member2, member3, vp, president, nonMember, nonMember2] = await ethers.getSigners();
  });

  beforeEach(async function () {
    CongressDAO = await ethers.getContractFactory("CongressDAO");
    congressDAO = await CongressDAO.deploy();
  });

  describe("addMember", function () {
    it("Should add a House member", async function () {
      await congressDAO.addMember(
        member1.address,
        "John",
        "Doe",
        0, // House
        "CA",
        12
      );
      const member = await congressDAO.members(member1.address);
      expect(member.memberType).to.equal(0);
    });

    it("Should prevent non-owner from adding members", async function () {
      await expect(
        congressDAO.connect(member1).addMember(
          member1.address,
          "John",
          "Doe",
          0,
          "CA",
          12
        )
      ).to.be.revertedWithCustomError(congressDAO, "NotOwner");
    });
  });

  describe("proposeBill", function () {
    beforeEach(async function () {
      await congressDAO.addMember(
        member1.address,
        "John",
        "Doe",
        0, // House
        "CA",
        12
      );
    });

    it("Should create a new bill", async function () {
      const now = await currentTime();
      await congressDAO.connect(member1).proposeBill(
        "Test Bill",
        "Enact...",
        ["Section 1"],
        ["Definition 1"],
        now + 3600, // Effective in 1 hour
        [member1.address],
        []
      );

      const billCount = await congressDAO.getBillHistoryLength();
      expect(billCount).to.equal(1);
    });

    it("Should prevent proposals with past effective dates", async function () {
      const now = await currentTime();
      await expect(
        congressDAO.connect(member1).proposeBill(
          "Invalid Bill",
          "Enact...",
          ["Section 1"],
          ["Definition 1"],
          now - 3600, // 1 hour ago
          [member1.address],
          []
        )
      ).to.be.revertedWithCustomError(congressDAO, "EffectiveDatePast");
    });
  });

  describe("castVote", function () {
    let billIndex;

    beforeEach(async function () {
      // Add members
      await congressDAO.addMember(member1.address, "House", "Member", 0, "CA", 1);
      await congressDAO.addMember(member2.address, "Senate", "Member", 1, "CA", 0);
      await congressDAO.addMember(vp.address, "VP", "Member", 2, "DC", 0);
      await congressDAO.addMember(president.address, "President", "Member", 4, "DC", 0);

      // Propose bill with proper timing
      const now = await currentTime();
      await congressDAO.connect(member1).proposeBill(
        "Voting Test Bill",
        "Enact...",
        ["Section 1"],
        ["Definition 1"],
        now + 3600, // Effective in 1 hour
        [member1.address],
        []
      );
      billIndex = 0;
    });

    it("Should record House votes", async function () {
      await congressDAO.connect(member1).castVote(billIndex, 1); // Yea
      const bill = await congressDAO.billHistory(billIndex);
      expect(bill.voting.houseVotes.yea).to.equal(1);
    });

    it("Should move to Senate after House approval", async function () {
      await congressDAO.connect(member1).castVote(billIndex, 1); // Yea
      const bill = await congressDAO.billHistory(billIndex);
      expect(bill.voting.passedHouse).to.be.true;
    });

    it("Should handle Senate tie with VP vote", async function () {
      // Add second senator
      await congressDAO.addMember(member3.address, "Senate2", "Member", 1, "NY", 0);

      // Pass House
      await congressDAO.connect(member1).castVote(billIndex, 1);

      // Create Senate tie
      await congressDAO.connect(member2).castVote(billIndex, 1); // Yea
      await congressDAO.connect(member3).castVote(billIndex, 0); // Nay

      let bill = await congressDAO.billHistory(billIndex);
      expect(bill.voting.tieBreakRequired).to.be.true;

      // VP breaks tie
      await congressDAO.connect(vp).castVote(billIndex, 1);
      bill = await congressDAO.billHistory(billIndex);
      expect(bill.voting.passedSenate).to.be.true;
    });

    it("Should require president for final approval", async function () {
      // Pass both chambers
      await congressDAO.connect(member1).castVote(billIndex, 1); // House
      await congressDAO.connect(member2).castVote(billIndex, 1); // Senate

      // President approves
      await congressDAO.connect(president).castVote(billIndex, 1);
      const bill = await congressDAO.billHistory(billIndex);
      expect(bill.voting.passed).to.be.true;
    });
  });

  describe("Edge Cases", function () {
    it("Should handle term expiration", async function () {
      // Add member with 2-year term
      await congressDAO.addMember(
        member1.address,
        "Temp",
        "Member",
        0, // House
        "TX",
        5
      );

      // Fast forward 3 years
      await ethers.provider.send("evm_increaseTime", [3 * 365 * 24 * 3600]);
      await ethers.provider.send("evm_mine");

      const now = await currentTime();
      await expect(
        congressDAO.connect(member1).proposeBill(
          "Expired Member Bill",
          "Enact...",
          ["Section 1"],
          ["Definition 1"],
          now + 3600,
          [member1.address],
          []
        )
      ).to.be.revertedWithCustomError(congressDAO, "NotActiveMember");
    });
  });

  describe("Nomination and Ratification", function () {
    beforeEach(async function () {
      // For nomination/ratification tests we add two active House members so that the threshold is > 0.
      await congressDAO.addMember(
        member1.address,
        "Alice",
        "Smith",
        0, // House
        "CA",
        1
      );
      await congressDAO.addMember(
        member2.address,
        "Bob",
        "Jones",
        0, // House
        "NY",
        2
      );
    });

    it("Should allow an active member to nominate a candidate", async function () {
      await congressDAO.connect(member1).nominateMember(
        nonMember.address,
        "Charlie",
        "Brown",
        0, // House nomination
        "TX",
        5
      );
      const nomination = await congressDAO.nominations(nonMember.address);
      expect(nomination.candidate).to.equal(nonMember.address);
      expect(nomination.fName).to.equal("Charlie");
      expect(nomination.memberType).to.equal(0);
    });

    it("Should revert nomination if candidate is already a member", async function () {
      // First, add nonMember as a full member.
      await congressDAO.addMember(
        nonMember.address,
        "Existing",
        "Member",
        0, // House
        "TX",
        5
      );
      await expect(
        congressDAO.connect(member1).nominateMember(
          nonMember.address,
          "Charlie",
          "Brown",
          0, // House
          "TX",
          5
        )
      ).to.be.revertedWithCustomError(congressDAO, "AlreadyMember");
    });

    it("Should revert nomination if candidate is already nominated", async function () {
      await congressDAO.connect(member1).nominateMember(
        nonMember.address,
        "Charlie",
        "Brown",
        0,
        "TX",
        5
      );
      await expect(
        congressDAO.connect(member2).nominateMember(
          nonMember.address,
          "Charlie",
          "Brown",
          0,
          "TX",
          5
        )
      ).to.be.revertedWithCustomError(congressDAO, "AlreadyNominated");
    });

    it("Should allow ratification and register candidate once threshold is met (House)", async function () {
      // For two House members, threshold = houseMembers.length/2 = 1.
      // Thus, candidate should not be registered until ratificationCount > 1.
      await congressDAO.connect(member1).nominateMember(
        nonMember.address,
        "Charlie",
        "Brown",
        0,
        "TX",
        5
      );
      // First ratification by member1 (ratificationCount becomes 1)
      await congressDAO.connect(member1).ratifyMember(nonMember.address);
      let isMemberFlag = await congressDAO.isMember(nonMember.address);
      expect(isMemberFlag).to.be.false;

      // Second ratification by member2 (ratificationCount becomes 2 > threshold)
      await congressDAO.connect(member2).ratifyMember(nonMember.address);
      isMemberFlag = await congressDAO.isMember(nonMember.address);
      expect(isMemberFlag).to.be.true;
    });

    it("Should revert if ratifying a non-existent nomination", async function () {
      await expect(
        congressDAO.connect(member1).ratifyMember(nonMember.address)
      ).to.be.revertedWith("Nomination does not exist");
    });

    it("Should revert if a member ratifies the same nomination twice", async function () {
      await congressDAO.connect(member1).nominateMember(
        nonMember.address,
        "Charlie",
        "Brown",
        0,
        "TX",
        5
      );
      await congressDAO.connect(member1).ratifyMember(nonMember.address);
      await expect(
        congressDAO.connect(member1).ratifyMember(nonMember.address)
      ).to.be.revertedWith("Already ratified");
    });

    it("Should revert ratification by an inactive member", async function () {
      // Use a fresh candidate (nonMember2) for this test.
      await congressDAO.connect(member1).nominateMember(
        nonMember2.address,
        "New",
        "Member",
        0,
        "TX",
        5
      );
      // Add an extra House member (member3) who we will render inactive.
      await congressDAO.addMember(
        member3.address,
        "Inactive",
        "Member",
        0, // House
        "FL",
        10
      );
      // Fast forward time so that member3's term expires.
      await ethers.provider.send("evm_increaseTime", [3 * 365 * 24 * 3600]);
      await ethers.provider.send("evm_mine");

      await expect(
        congressDAO.connect(member3).ratifyMember(nonMember2.address)
      ).to.be.revertedWithCustomError(congressDAO, "NotActiveMember");
    });
  });
});
