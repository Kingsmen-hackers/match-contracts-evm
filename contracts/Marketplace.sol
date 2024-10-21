// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/AggregatorV3Interface.sol";

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

contract Marketplace {
    event UserCreated(
        address indexed userAddress,
        uint256 userId,
        string username,
        uint8 accountType
    );
    event UserUpdated(
        address indexed userAddress,
        uint256 userId,
        string username,
        uint8 accountType
    );
    event StoreCreated(
        address indexed sellerAddress,
        uint256 storeId,
        string storeName,
        int256 latitude,
        int256 longitude
    );

    event OfferAccepted(
        uint256 indexed offerId,
        address indexed buyerAddress,
        bool isAccepted
    );
    event RequestCreated(
        uint256 indexed requestId,
        address indexed buyerAddress,
        string requestName,
        int256 latitude,
        int256 longitude,
        string[] images,
        uint8 lifecycle,
        string description,
        uint256 buyerId,
        uint256[] sellerIds,
        int256 sellersPriceQuote,
        uint256 lockedSellerId,
        uint256 createdAt,
        uint256 updatedAt
    );

    event OfferCreated(
        uint256 indexed offerId,
        address indexed sellerAddress,
        string storeName,
        uint256 price,
        uint256 requestId,
        string[] images,
        uint256 sellerId,
        uint256[] sellerIds
    );

    event RequestAccepted(
        uint256 indexed requestId,
        uint256 indexed offerId,
        uint256 indexed sellerId,
        uint256 updatedAt,
        uint256 sellersPriceQuote
    );

    event OfferRemoved(uint256 indexed offerId, address indexed sellerAddress);

    event LocationEnabled(bool enabled, uint256 userId);

    enum AccountType {
        BUYER,
        SELLER
    }

    enum CoinPayment {
        ETH,
        USDT
    }
    enum RequestLifecycle {
        PENDING,
        ACCEPTED_BY_SELLER,
        ACCEPTED_BY_BUYER,
        REQUEST_LOCKED,
        PAID,
        COMPLETED
    }

    struct Location {
        int256 latitude;
        int256 longitude;
    }

    struct Store {
        uint256 id;
        string name;
        string description;
        string phone;
        Location location;
    }

    struct PaymentInfo {
        address authority;
        uint256 requestId;
        address buyer;
        address seller;
        uint256 amount;
        CoinPayment token;
        uint256 createdAt;
        uint256 updatedAt;
    }

    mapping(address => mapping(uint256 => Store)) public userStores;
    mapping(address => uint256[]) public userStoreIds;

    struct User {
        uint256 id;
        string username;
        string phone;
        Location location;
        uint256 createdAt;
        uint256 updatedAt;
        AccountType accountType;
        bool location_enabled;
    }

    struct Request {
        uint256 id;
        string name;
        uint256 buyerId;
        uint256 sellersPriceQuote;
        uint256[] sellerIds;
        uint256[] offerIds;
        uint256 lockedSellerId;
        string description;
        string[] images;
        uint256 createdAt;
        RequestLifecycle lifecycle;
        Location location;
        uint256 updatedAt;
        bool paid;
        uint256 acceptedOfferId;
    }

    struct Offer {
        uint256 id;
        uint256 price;
        string[] images;
        uint256 requestId;
        string storeName;
        uint256 sellerId;
        bool isAccepted;
        uint256 createdAt;
        uint256 updatedAt;
        address authority;
    }

    // Custom errors with Marketplace__ prefix
    error Marketplace__OnlySellersAllowed();
    error Marketplace__UnauthorizedBuyer();
    error Marketplace__OnlyBuyersAllowed();
    error Marketplace__UnSupportedChainId();
    error Marketplace__OfferAlreadyAccepted();
    error Marketplace__InvalidAccountType();
    error Marketplace__OfferAlreadyExists();
    error Marketplace__UnauthorizedRemoval();
    error Marketplace__RequestNotAccepted();
    error Marketplace__RequestAlreadyPaid();
    error Marketplace__RequestNotLocked();
    error Marketplace__InsufficientFunds();
    error Marketplace__OfferNotRemovable();
    error Marketplace__IndexOutOfBounds();
    error Marketplace__RequestLocked();
    error Marketplace_InvalidUser();
    error Marketplace_UserAlreadyExists();

    mapping(address => User) public users;
    mapping(uint256 => Request) public requests;
    mapping(uint256 => Offer) public offers;
    mapping(uint256 => PaymentInfo) public requestPaymentInfo;

    uint256 private _userCounter;
    uint256 private _storeCounter;
    uint256 private _requestCounter;
    uint256 private _offerCounter;
    uint256 private _requestPaymentCounter;

    uint256 constant TIME_TO_LOCK = 60;
    address constant USDT = address(0);

    function createUser(
        string memory _username,
        string memory _phone,
        int256 _latitude,
        int256 _longitude,
        AccountType _accountType
    ) public {
        User storage user = users[msg.sender];
        if (user.id != 0) {
            revert Marketplace_UserAlreadyExists();
        }

        if (
            _accountType != AccountType.BUYER &&
            _accountType != AccountType.SELLER
        ) {
            revert Marketplace__InvalidAccountType();
        }

        Location memory userLocation = Location(_latitude, _longitude);

        _userCounter++;
        uint256 userId = _userCounter;

        users[msg.sender] = User(
            userId,
            _username,
            _phone,
            userLocation,
            block.timestamp,
            block.timestamp,
            _accountType,
            true
        );

        emit UserCreated(msg.sender, userId, _username, uint8(_accountType));
    }

    function updateUser(
        string memory _username,
        string memory _phone,
        int256 _latitude,
        int256 _longitude,
        AccountType _accountType
    ) public {
        User storage user = users[msg.sender];

        if (user.id == 0) {
            revert Marketplace_InvalidUser();
        }

        // Update user information
        user.username = _username;
        user.phone = _phone;
        user.location = Location(_latitude, _longitude);
        user.updatedAt = block.timestamp;
        user.accountType = _accountType;

        emit UserUpdated(
            msg.sender,
            user.id,
            _username,
            uint8(user.accountType)
        );
    }

    function createStore(
        string memory _name,
        string memory _description,
        string memory _phone,
        int256 _latitude,
        int256 _longitude
    ) public {
        if (users[msg.sender].accountType != AccountType.SELLER) {
            revert Marketplace__OnlySellersAllowed();
        }

        Location memory storeLocation = Location(_latitude, _longitude);

        _storeCounter++;
        uint256 storeId = _storeCounter;

        Store memory newStore = Store(
            storeId,
            _name,
            _description,
            _phone,
            storeLocation
        );
        userStores[msg.sender][storeId] = newStore;
        userStoreIds[msg.sender].push(storeId);
        emit StoreCreated(msg.sender, storeId, _name, _latitude, _longitude);
    }

    function createRequest(
        string memory _name,
        string memory _description,
        string[] memory _images,
        int256 _latitude,
        int256 _longitude
    ) public {
        if (users[msg.sender].accountType != AccountType.BUYER) {
            revert Marketplace__OnlyBuyersAllowed();
        }

        Location memory requestLocation = Location(_latitude, _longitude);

        _requestCounter++;
        uint256 requestId = _requestCounter;

        Request memory newRequest = Request(
            requestId,
            _name,
            users[msg.sender].id,
            0,
            new uint256[](0),
            new uint256[](0),
            0,
            _description,
            _images,
            block.timestamp,
            RequestLifecycle.PENDING,
            requestLocation,
            block.timestamp,
            false,
            0
        );

        requests[requestId] = newRequest;
        emit RequestCreated(
            requestId,
            msg.sender,
            _name,
            _latitude,
            _longitude,
            _images,
            uint8(RequestLifecycle.PENDING),
            _description,
            users[msg.sender].id,
            new uint256[](0),
            0,
            0,
            block.timestamp,
            block.timestamp
        );
    }

    function deleteRequest(uint256 _requestId) public {
        Request storage request = requests[_requestId];

        if (request.buyerId != users[msg.sender].id) {
            revert Marketplace__UnauthorizedRemoval();
        }

        if (request.lifecycle != RequestLifecycle.PENDING) {
            revert Marketplace__RequestLocked();
        }

        delete requests[_requestId];
    }

    function markRequestAsCompleted(uint256 _requestId) public {
        Request storage request = requests[_requestId];

        if (request.buyerId != users[msg.sender].id) {
            revert Marketplace__UnauthorizedRemoval();
        }

        if (request.lifecycle != RequestLifecycle.ACCEPTED_BY_BUYER) {
            revert Marketplace__RequestNotAccepted();
        }

        if (request.updatedAt + TIME_TO_LOCK > block.timestamp) {
            revert Marketplace__RequestNotLocked();
        }

        request.lifecycle = RequestLifecycle.COMPLETED;
        request.updatedAt = block.timestamp;
    }

    function getAggregatorV3() public view returns (AggregatorV3Interface) {
        if (block.chainid == 1) {
            return
                AggregatorV3Interface(
                    0x8A753747A1Fa494EC906cE90E9f37563A8AF630e
                );
        } else if (block.chainid == 11155111) {
            return
                AggregatorV3Interface(
                    0x694AA1769357215DE4FAC081bf1f309aDC325306
                );
        } else {
            revert Marketplace__UnSupportedChainId();
        }
    }

    function payForRequestToken(
        uint256 requestId,
        CoinPayment coin
    ) external payable {
        Request storage request = requests[requestId];
        Offer storage offer = offers[request.acceptedOfferId];

        if (request.buyerId != users[msg.sender].id) {
            revert Marketplace__UnauthorizedBuyer();
        }

        if (request.lifecycle != RequestLifecycle.ACCEPTED_BY_BUYER) {
            revert Marketplace__RequestNotAccepted();
        }

        if (request.updatedAt + TIME_TO_LOCK > block.timestamp) {
            revert Marketplace__RequestNotLocked();
        }

        if (!offer.isAccepted) {
            revert Marketplace__RequestNotAccepted();
        }

        if (request.paid) {
            revert Marketplace__RequestAlreadyPaid();
        }

        request.paid = true;
        request.lifecycle = RequestLifecycle.PAID;

        uint256 paymentId = _requestPaymentCounter;

        PaymentInfo memory newPaymentInfo = PaymentInfo(
            msg.sender,
            requestId,
            msg.sender,
            offer.authority,
            0,
            coin,
            block.timestamp,
            block.timestamp
        );

        if (coin == CoinPayment.USDT) {
            AggregatorV3Interface priceFeed = getAggregatorV3();
            (, int256 price, , , ) = priceFeed.latestRoundData();
            uint256 usdtAmount = (offer.price * uint256(price)) / 1e8;
            newPaymentInfo.amount = usdtAmount;

            IERC20 usdt = IERC20(USDT);
            if (!usdt.transferFrom(msg.sender, address(this), usdtAmount)) {
                revert Marketplace__InsufficientFunds();
            }
        } else {
            revert Marketplace__InsufficientFunds();
        }
        requestPaymentInfo[paymentId] = newPaymentInfo;
        _requestPaymentCounter++;
    }

    function payForRequest(
        uint256 requestId,
        CoinPayment coin
    ) external payable {
        Request storage request = requests[requestId];
        Offer storage offer = offers[request.acceptedOfferId];

        if (request.buyerId != users[msg.sender].id) {
            revert Marketplace__UnauthorizedBuyer();
        }

        if (request.lifecycle != RequestLifecycle.ACCEPTED_BY_BUYER) {
            revert Marketplace__RequestNotAccepted();
        }

        if (request.updatedAt + TIME_TO_LOCK > block.timestamp) {
            revert Marketplace__RequestNotLocked();
        }

        if (!offer.isAccepted) {
            revert Marketplace__RequestNotAccepted();
        }

        if (request.paid) {
            revert Marketplace__RequestAlreadyPaid();
        }

        request.paid = true;
        request.lifecycle = RequestLifecycle.PAID;

        uint256 paymentId = _requestPaymentCounter;

        PaymentInfo memory newPaymentInfo = PaymentInfo(
            msg.sender,
            requestId,
            msg.sender,
            offer.authority,
            0,
            coin,
            block.timestamp,
            block.timestamp
        );
        requestPaymentInfo[paymentId] = newPaymentInfo;

        if (coin == CoinPayment.ETH) {
            if (msg.value < offer.price) {
                revert Marketplace__InsufficientFunds();
            }
            newPaymentInfo.amount = offer.price;
        } else {
            revert Marketplace__InsufficientFunds();
        }
        requestPaymentInfo[paymentId] = newPaymentInfo;
        _requestPaymentCounter++;
    }

    function toggleLocation(bool enabled) public {
        users[msg.sender].location_enabled = enabled;
        emit LocationEnabled(enabled, users[msg.sender].id);
    }

    function getLocationPreference() public view returns (bool) {
        return users[msg.sender].location_enabled;
    }

    function createOffer(
        uint256 _price,
        string[] memory _images,
        uint256 _requestId,
        string memory _storeName
    ) public {
        if (users[msg.sender].accountType != AccountType.SELLER) {
            revert Marketplace__OnlySellersAllowed();
        }

        Request storage request = requests[_requestId];

        if (
            block.timestamp > request.updatedAt + TIME_TO_LOCK &&
            request.lifecycle == RequestLifecycle.ACCEPTED_BY_BUYER
        ) {
            revert Marketplace__RequestLocked();
        }

        _offerCounter++;
        uint256 offerId = _offerCounter;

        Offer memory newOffer = Offer(
            offerId,
            _price,
            _images,
            _requestId,
            _storeName,
            users[msg.sender].id,
            false,
            block.timestamp,
            block.timestamp,
            msg.sender
        );
        offers[offerId] = newOffer;
        request.sellerIds.push(newOffer.sellerId);

        if (request.lifecycle == RequestLifecycle.PENDING) {
            request.lifecycle = RequestLifecycle.ACCEPTED_BY_SELLER;
        }

        emit OfferCreated(
            offerId,
            msg.sender,
            _storeName,
            _price,
            _requestId,
            _images,
            users[msg.sender].id,
            request.sellerIds
        );
        // mapping(address => mapping(uint256 => Offer)) offers;
    }

    function acceptOffer(uint256 _offerId) public {
        Offer storage offer = offers[_offerId];
        Request storage request = requests[offer.requestId];

        if (users[msg.sender].accountType != AccountType.BUYER) {
            revert Marketplace__OnlyBuyersAllowed();
        }

        if (requests[offer.requestId].buyerId != users[msg.sender].id) {
            revert Marketplace__UnauthorizedBuyer();
        }

        if (offer.isAccepted) {
            revert Marketplace__OfferAlreadyAccepted();
        }

        if (
            block.timestamp > request.updatedAt + TIME_TO_LOCK &&
            request.lifecycle == RequestLifecycle.ACCEPTED_BY_BUYER
        ) {
            revert Marketplace__RequestLocked();
        }

        for (uint i = 0; i < request.offerIds.length; i++) {
            uint256 offerId = request.offerIds[i];
            Offer storage previousOffer = offers[offerId];
            previousOffer.isAccepted = false;
            emit OfferAccepted(previousOffer.id, msg.sender, false);
        }

        offer.isAccepted = true;
        offer.updatedAt = block.timestamp;
        request.offerIds.push(offer.id);
        request.lockedSellerId = offer.sellerId;
        request.sellersPriceQuote = offer.price;
        request.acceptedOfferId = offer.id;
        request.lifecycle = RequestLifecycle.ACCEPTED_BY_BUYER;
        request.updatedAt = block.timestamp;

        emit RequestAccepted(
            request.id,
            offer.id,
            offer.sellerId,
            request.updatedAt,
            request.sellersPriceQuote
        );
        emit OfferAccepted(offer.id, msg.sender, true);
    }

    function userStoreCount(address user) public view returns (uint256) {
        return userStoreIds[user].length;
    }

    function getRequestImagesLength(
        uint256 requestId
    ) public view returns (uint256) {
        return requests[requestId].images.length;
    }

    function getRequestImageByIndex(
        uint256 requestId,
        uint256 index
    ) public view returns (string memory) {
        if (index >= requests[requestId].images.length) {
            revert Marketplace__IndexOutOfBounds();
        }
        return requests[requestId].images[index];
    }

    function getRequestSellerIdsLength(
        uint256 requestId
    ) public view returns (uint256) {
        return requests[requestId].sellerIds.length;
    }

    function getRequestSellerIdByIndex(
        uint256 requestId,
        uint256 index
    ) public view returns (uint256) {
        if (index >= requests[requestId].sellerIds.length) {
            revert Marketplace__IndexOutOfBounds();
        }
        return requests[requestId].sellerIds[index];
    }

    function getOfferImagesLength(
        uint256 offerId
    ) public view returns (uint256) {
        return offers[offerId].images.length;
    }

    function getOfferImageByIndex(
        uint256 offerId,
        uint256 index
    ) public view returns (string memory) {
        if (index >= offers[offerId].images.length) {
            revert Marketplace__IndexOutOfBounds();
        }
        return offers[offerId].images[index];
    }
}
