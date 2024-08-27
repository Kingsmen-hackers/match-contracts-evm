const { assert, expect } = require("chai");
const { ethers } = require("hardhat");
const { getNamedAccounts, network } = require("hardhat");
const testUser = {
  username: "TestUser",
  phone: "1234567890",
  latitude: 37.7749 * 1e6,
  longitude: -122.4194 * 1e6,
  accountType: AccountType.BUYER, // BUYER
};

const testStore = {
  name: "TestStore",
  description: "A test store",
  latitude: 37.7749 * 1e6,
  longitude: -122.4194 * 1e6,
};

const testRequest = {
  name: "TestRequest",
  description: "A test request",
  images: ["img1.jpg", "img2.jpg"],
  latitude: 37.7749 * 1e6,
  longitude: -122.4194 * 1e6,
};

const testOffer = {
  price: 1000,
  images: ["offer_img1.jpg", "offer_img2.jpg"],
  requestId: "1",
  storeName: "TestStore",
};
describe("Marketplace", function () {
  let matchContract, deployer;
  const chainId = network.config.chainId;
  let accounts;
  beforeEach(async function () {
    accounts = await ethers.getSigners();
    deployer = (await getNamedAccounts()).deployer;
    await deployments.fixture(["all"]);
    matchContract = await ethers.getContract("Marketplace", deployer);
  });

  describe("User Creation", function () {
    it("Should allow a user to create a user account", async function () {
      await matchContract
        .connect(accounts[0])
        .createUser(
          testUser.username,
          testUser.phone,
          testUser.latitude,
          testUser.longitude,
          testUser.accountType
        );
      const user = await matchContract.users(accounts[0]);
      console.log(user);

      expect(user.username).to.equal(testUser.username);
      expect(user.phone).to.equal(testUser.phone);
      expect(user.latitude).to.equal(testUser.latitude);
      expect(user.longitude).to.equal(testUser.longitude);
      expect(user.accountType).to.equal(testUser.accountType);
    });
  });
});
