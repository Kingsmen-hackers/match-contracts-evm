const { assert, expect } = require("chai");
const { ethers } = require("hardhat");
const { getNamedAccounts, network } = require("hardhat");

const AccountType = {
  BUYER: 0,
  SELLER: 1,
};

const testUser = {
  username: "TestUser",
  phone: "1234567890",
  latitude: 37.7749 * 1e6,
  longitude: -122.4194 * 1e6,
  accountType: AccountType.BUYER, // BUYER
};

const testUserUpdate = {
  username: "TestUserUpdate",
  phone: "0987654321",
  latitude: 37.7749 * 1e6,
  longitude: -122.4194 * 1e6,
  accountType: AccountType.SELLER, // SELLER
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
    await matchContract
      .connect(accounts[0])
      .createUser(
        testUser.username,
        testUser.phone,
        testUser.latitude,
        testUser.longitude,
        testUser.accountType
      );
  });

  describe("User Creation", function () {
    it("Should allow a user to create a user account", async function () {
      const user = await matchContract.users(accounts[0].address);

      expect(user.username).to.equal(testUser.username);
      expect(user.phone).to.equal(testUser.phone);
      expect(user.location.latitude).to.equal(testUser.latitude);
      expect(user.location.longitude).to.equal(testUser.longitude);
      expect(user.accountType).to.equal(testUser.accountType);
    });

    it("Should allow a user to update a user account", async function () {
      await matchContract
        .connect(accounts[0])
        .updateUser(
          testUserUpdate.username,
          testUserUpdate.phone,
          testUserUpdate.latitude,
          testUserUpdate.longitude,
          testUserUpdate.accountType
        );

      const user = await matchContract.users(accounts[0].address);

      expect(user.username).to.equal(testUserUpdate.username);
      expect(user.phone).to.equal(testUserUpdate.phone);
      expect(user.location.latitude).to.equal(testUserUpdate.latitude);
      expect(user.location.longitude).to.equal(testUserUpdate.longitude);
      expect(user.accountType).to.equal(testUserUpdate.accountType);
    });
  });

  describe("Store Creation", function () {
    it("Should allow a user to create a store", async function () {
      await matchContract
        .connect(accounts[0])
        .updateUser(
          testUserUpdate.username,
          testUserUpdate.phone,
          testUserUpdate.latitude,
          testUserUpdate.longitude,
          testUserUpdate.accountType
        );
      const storeInfo = await matchContract
        .connect(accounts[0])
        .createStore(
          testStore.name,
          testStore.description,
          testUser.phone,
          testStore.latitude,
          testStore.longitude
        );

      const receipt = await storeInfo.wait();

      const storeId = receipt.events[0].args.storeId;

      const store = await matchContract.userStores(
        accounts[0].address,
        storeId
      );

      expect(store.name).to.equal(testStore.name);
      expect(store.description).to.equal(testStore.description);
      expect(store.phone).to.equal(testUser.phone);
      expect(store.location.latitude).to.equal(testStore.latitude);
      expect(store.location.longitude).to.equal(testStore.longitude);
    });
  });

  describe("Request Creation", function () {
    it("Should allow a user to create a request", async function () {
      const requestInfo = await matchContract
        .connect(accounts[0])
        .createRequest(
          testRequest.name,
          testRequest.description,
          testRequest.images,
          testRequest.latitude,
          testRequest.longitude
        );

      const receipt = await requestInfo.wait();

      const requestId = receipt.events[0].args.requestId;

      const request = await matchContract.requests(requestId);

      expect(request.name).to.equal(testRequest.name);
      expect(request.description).to.equal(testRequest.description);
      expect(request.location.latitude).to.equal(testRequest.latitude);
      expect(request.location.longitude).to.equal(testRequest.longitude);
    });
  });

  describe("Offer Creation", function () {
    it("Should allow a user to create an offer", async function () {
      await matchContract
        .connect(accounts[0])
        .createRequest(
          testRequest.name,
          testRequest.description,
          testRequest.images,
          testRequest.latitude,
          testRequest.longitude
        );

      await matchContract
        .connect(accounts[0])
        .updateUser(
          testUserUpdate.username,
          testUserUpdate.phone,
          testUserUpdate.latitude,
          testUserUpdate.longitude,
          testUserUpdate.accountType
        );
      await matchContract
        .connect(accounts[0])
        .createStore(
          testStore.name,
          testStore.description,
          testUser.phone,
          testStore.latitude,
          testStore.longitude
        );

      const offerInfo = await matchContract
        .connect(accounts[0])
        .createOffer(testOffer.price, testOffer.images, 1, testStore.name);

      const receipt = await offerInfo.wait();

      const offerId = receipt.events[0].args.offerId;

      const offer = await matchContract.offers(offerId);

      expect(offer.price).to.equal(testOffer.price);
      expect(offer.requestId).to.equal(1);
      expect(offer.storeName).to.equal(testStore.name);
    });
  });

  describe("Offer Acceptance", function () {
    it("Should allow a user to accept an offer", async function () {
      await matchContract
        .connect(accounts[0])
        .createRequest(
          testRequest.name,
          testRequest.description,
          testRequest.images,
          testRequest.latitude,
          testRequest.longitude
        );

      await matchContract
        .connect(accounts[0])
        .updateUser(
          testUserUpdate.username,
          testUserUpdate.phone,
          testUserUpdate.latitude,
          testUserUpdate.longitude,
          testUserUpdate.accountType
        );
      await matchContract
        .connect(accounts[0])
        .createStore(
          testStore.name,
          testStore.description,
          testUser.phone,
          testStore.latitude,
          testStore.longitude
        );

      await matchContract
        .connect(accounts[0])
        .createOffer(testOffer.price, testOffer.images, 1, testStore.name);

      await matchContract
        .connect(accounts[0])
        .updateUser(
          testUser.username,
          testUser.phone,
          testUser.latitude,
          testUser.longitude,
          testUser.accountType
        );

      await matchContract.connect(accounts[0]).acceptOffer(1);

      const offer = await matchContract.offers(1);

      expect(offer.isAccepted).to.equal(true);
    });
  });
});
