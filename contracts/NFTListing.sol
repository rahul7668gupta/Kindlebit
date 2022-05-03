// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Operator.sol";
import "./Whitelist.sol";
import "./ListingFeeProvider.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";

// @title ERC-721 Non-Fungible Token Standard
// @dev Include interface for both new and old functions
interface ERC721TokenReceiver {
    function onERC721Received(
        address _from,
        uint256 _tokenId,
        bytes memory data
    ) external returns (bytes4);

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes memory data
    ) external returns (bytes4);
}

contract NFTListing is Operator {
    // Callback values from zepellin ERC721Receiver.sol
    // Old ver: bytes4(keccak256("onERC721Received(address,uint256,bytes)")) = 0xf0b9e5ba;
    bytes4 constant ERC721_RECEIVED_OLD = 0xf0b9e5ba;
    // New ver w/ operator: bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")) = 0xf0b9e5ba;
    bytes4 constant ERC721_RECEIVED = 0x150b7a02;

    Whitelist public whitelist =
        Whitelist(0xA8CedD578fed14f07C3737bF42AD6f04FAAE3978); // Main Net
    ListingFeeProvider public FeeProvider =
        ListingFeeProvider(0x58D36571250D91eF5CE90869E66Cd553785364a2); // Main Net

    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; //Main Net

    uint256 public defaultExpiry = 7 days; // default expiry is 7 days

    enum Currency {
        WETH
    }

    struct Listing {
        Currency currency; // WETH
        address seller; // seller address
        address token; // token contract
        uint256 tokenId; // token id
        uint256 price; // Big number in WETH
        uint256 createdAt; // timestamp
        uint256 expiry; // createdAt + defaultExpiry
    }

    mapping(bytes32 => Listing) public listings;

    event LogListingCreated(
        address _seller,
        address _contract,
        uint256 _tokenId,
        uint256 _createdAt,
        uint256 _expiry
    );
    event LogListingExtended(
        address _seller,
        address _contract,
        uint256 _tokenId,
        uint256 _createdAt,
        uint256 _expiry
    );
    event LogItemSold(
        address _buyer,
        address _seller,
        address _contract,
        uint256 _tokenId,
        uint256 _price,
        Currency _currency,
        uint256 _soldAt
    );
    event LogItemWithdrawn(
        address _seller,
        address _contract,
        uint256 _tokenId,
        uint256 _withdrawnAt
    );
    event LogItemExtended(
        address _contract,
        uint256 _tokenId,
        uint256 _modifiedAt,
        uint256 _expiry
    );

    modifier onlyWhitelisted(address _contract) {
        require(
            whitelist.isWhitelisted(_contract),
            "Contract not in whitelist."
        );
        _;
    }

    function getHashKey(address _contract, uint256 _tokenId)
        public
        pure
        returns (bytes32 key)
    {
        key = _getHashKey(_contract, _tokenId);
    }

    function getFee(
        uint256 _price,
        address _currency,
        address _buyer,
        address _seller,
        address _token
    ) public view returns (uint256 percent, uint256 fee) {
        (percent, fee) = FeeProvider.getFee(
            _price,
            _currency,
            _buyer,
            _seller,
            _token
        );
    }

    function onERC721Received(
        address _from,
        uint256 _tokenId,
        bytes memory _extraData
    ) external returns (bytes4) {
        _deposit(_from, msg.sender, _tokenId, _extraData);
        return ERC721_RECEIVED_OLD;
    }

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes memory _extraData
    ) external returns (bytes4) {
        _deposit(_from, msg.sender, _tokenId, _extraData);
        return ERC721_RECEIVED;
    }

    function extendItem(address _contract, uint256 _tokenId)
        public
        onlyWhitelisted(_contract)
        returns (bool)
    {
        bytes32 key = _getHashKey(_contract, _tokenId);
        address seller = listings[key].seller;

        require(seller == msg.sender, "Only seller can extend listing.");
        require(listings[key].expiry > 0, "Item not listed.");

        listings[key].expiry = block.timestamp + defaultExpiry;

        emit LogListingExtended(
            seller,
            _contract,
            _tokenId,
            listings[key].createdAt,
            listings[key].expiry
        );

        return true;
    }

    function withdrawItem(address _contract, uint256 _tokenId)
        public
        onlyWhitelisted(_contract)
    {
        bytes32 key = _getHashKey(_contract, _tokenId);
        address seller = listings[key].seller;

        require(seller == msg.sender, "Only seller can withdraw listing.");

        IERC721 nftToken = IERC721(_contract);
        nftToken.transferFrom(address(this), seller, _tokenId);

        emit LogItemWithdrawn(seller, _contract, _tokenId, block.timestamp);

        delete (listings[key]);
    }

    function buyWithETH(address _token, uint256 _tokenId)
        public
        payable
        onlyWhitelisted(_token)
    {
        _buy(_token, _tokenId, Currency.WETH, msg.value, msg.sender);
    }

    function updateFeeProvider(address _newAddr) public onlyOperator {
        require(_newAddr != address(0), "Invalid contract address.");
        FeeProvider = ListingFeeProvider(_newAddr);
    }

    function updateWhitelist(address _newAddr) public onlyOperator {
        require(_newAddr != address(0), "Invalid contract address.");
        whitelist = Whitelist(_newAddr);
    }

    function updateExpiry(uint256 _days) public onlyOperator {
        require(_days > 0, "Invalid number of days.");
        defaultExpiry = _days * 1 days;
    }

    function withdrawETH() public payable onlyOwner {
        payable(owner).transfer(msg.value);
    }

    function _getHashKey(address _contract, uint256 _tokenId)
        internal
        pure
        returns (bytes32 key)
    {
        key = keccak256(abi.encodePacked(_contract, _tokenId));
    }

    function _newListing(
        address _seller,
        address _contract,
        uint256 _tokenId,
        uint256 _price,
        Currency _currency
    ) internal {
        bytes32 key = _getHashKey(_contract, _tokenId);
        uint256 createdAt = block.timestamp;
        uint256 expiry = block.timestamp + defaultExpiry;
        listings[key].currency = _currency;
        listings[key].seller = _seller;
        listings[key].token = _contract;
        listings[key].tokenId = _tokenId;
        listings[key].price = _price;
        listings[key].createdAt = createdAt;
        listings[key].expiry = expiry;

        emit LogListingCreated(_seller, _contract, _tokenId, createdAt, expiry);
    }

    function _deposit(
        address _seller,
        address _contract,
        uint256 _tokenId,
        bytes memory _extraData
    ) internal onlyWhitelisted(_contract) {
        uint256 price;
        uint256 currencyUint;
        (currencyUint, price) = _decodePriceData(_extraData);
        Currency currency = Currency(currencyUint);

        require(price > 0, "Invalid price.");

        _newListing(_seller, _contract, _tokenId, price, currency);
    }

    // @dev handles purchase logic for WETH
    function _buy(
        address _token,
        uint256 _tokenId,
        Currency _currency,
        uint256 _price,
        address _buyer
    ) internal {
        bytes32 key = _getHashKey(_token, _tokenId);
        Currency currency = listings[key].currency;
        address seller = listings[key].seller;

        address currencyAddress = _currency == Currency.WETH
            ? address(WETH)
            : address(0);

        require(currency == _currency, "Wrong currency.");
        require(_price > 0 && _price == listings[key].price, "Invalid price.");
        require(listings[key].expiry > block.timestamp, "Item expired.");

        IERC721 nftToken = IERC721(_token);
        require(
            nftToken.ownerOf(_tokenId) == address(this),
            "Item is not available."
        );

        if (_currency == Currency.WETH) {
            // Transfer WETH to marketplace contract
            require(
                IERC20(WETH).transferFrom(_buyer, address(this), _price),
                "WETH payment transfer failed."
            );
        }

        nftToken.transferFrom(address(this), _buyer, _tokenId);

        uint256 fee;
        (, fee) = getFee(_price, currencyAddress, _buyer, seller, _token); // getFee returns percentFee and fee, we only need fee

        if (_currency == Currency.WETH) {
            IERC20 token = IERC20(WETH);

            token.transfer(seller, _price - fee);
        } else {
            require(
                payable(seller).send(_price - fee) == true,
                "Transfer to seller failed."
            );
        }

        emit LogItemSold(
            _buyer,
            seller,
            _token,
            _tokenId,
            _price,
            currency,
            block.timestamp
        );

        delete (listings[key]);
    }

    function _decodePriceData(bytes memory _extraData)
        internal
        pure
        returns (uint256 _currency, uint256 _price)
    {
        // Deserialize _extraData
        uint256 offset = 64;
        _price = _bytesToUint256(offset, _extraData);
        offset -= 32;
        _currency = _bytesToUint256(offset, _extraData);
    }

    function _decodeBuyData(bytes memory _extraData)
        internal
        pure
        returns (address _contract, uint256 _tokenId)
    {
        // Deserialize _extraData
        uint256 offset = 64;
        _tokenId = _bytesToUint256(offset, _extraData);
        offset -= 32;
        _contract = _bytesToAddress(offset, _extraData);
    }

    function _bytesToUint256(uint256 _offst, bytes memory _input)
        internal
        pure
        returns (uint256 _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }

    function _bytesToAddress(uint256 _offst, bytes memory _input)
        internal
        pure
        returns (address _output)
    {
        assembly {
            _output := mload(add(_input, _offst))
        }
    }
}
