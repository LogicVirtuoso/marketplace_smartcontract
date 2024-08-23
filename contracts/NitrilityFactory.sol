// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./utils/Counters.sol";
import "./utils/SafeMath.sol";
import "./NitrilityLicense.sol";
import "./NitrilityCommon.sol";

contract NitrilityFactory is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.Bytes32Set private sellerIdSet;
    mapping(string => address) private idToArtistCollectionAddress;
    mapping(string => EnumerableSet.AddressSet) private sellerIdToAddresses;
    mapping(string => uint256) private idToWithdrawal;
    mapping(uint256 => SoldLicense) private idToSoldLicense;

    address public marketOwner;
    address public auctionAddr;

    Counters.Counter private tokenIds;

    uint256 public constant decimals = 18;
    uint256 public constant gasFee = 1e13; // 0.00000000001 ether or 1e15 wei
    uint256 public constant marketplaceFee = 25; // 2.5 %

    uint256 public nitrilityRevenue;
    uint256 public socialRevenue;

    struct SoldLicense {
        string trackId;
        string tokenURI;
        string sellerId;
        address buyerAddr;
        uint256 price;
        uint256 counts;
        NitrilityCommon.LicensingType licensingType;
        NitrilityCommon.EventTypes eventType;
        NitrilityCommon.Exclusivity exclusivity;
    }

    event CollectionCreated(string sellerId, address collectionAddr);
    event SoldLicenseEvent(uint256 tokenId);
    event LicenseBurnt(uint256 tokenId);
    event LicenseTransfer(uint256 tokenId, address from, address to);

    constructor() Ownable(msg.sender) ReentrancyGuard() {
        marketOwner = msg.sender;
    }

    receive() external payable {}

    modifier onlyCaller() {
        require(
            msg.sender == owner() || msg.sender == marketOwner,
            "Caller is not authorized"
        );
        _;
    }

    modifier onlyAuction() {
        require(
            msg.sender == auctionAddr,
            "Caller is not the auction contract"
        );
        _;
    }

    function setMarketOwner(address _marketOwner) external onlyCaller {
        marketOwner = _marketOwner;
    }

    function setAuctionAddr(address _auctionAddr) external onlyCaller {
        auctionAddr = _auctionAddr;
    }

    function isCollection(address collection) internal view returns (bool) {
        for (uint256 i = 0; i < sellerIdSet.length(); i++) {
            string memory sellerId = bytes32ToString(sellerIdSet.at(i));
            address collectionAddr = idToArtistCollectionAddress[sellerId];
            if (collectionAddr == collection) {
                return true;
            }
        }
        return false;
    }

    function stringToBytes32(
        string memory str
    ) internal pure returns (bytes32 result) {
        require(bytes(str).length <= 32, "String too long");
        assembly {
            result := mload(add(str, 32))
        }
    }

    function bytes32ToString(
        bytes32 _bytes32
    ) internal pure returns (string memory) {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    function emitLicenseburnt(uint256 tokenId) internal {
        emit LicenseBurnt(tokenId);
    }

    function emitLicenseTransfer(
        uint256 tokenId,
        address from,
        address to
    ) internal {
        emit LicenseTransfer(tokenId, from, to);
    }

    function createCollection(string calldata sellerId) internal {
        if (idToArtistCollectionAddress[sellerId] == address(0)) {
            NitrilityLicense newContract = new NitrilityLicense(
                address(this),
                sellerId
            );
            idToArtistCollectionAddress[sellerId] = address(newContract);
            sellerIdSet.add(stringToBytes32(sellerId));
            emit CollectionCreated(sellerId, address(newContract));
        }
    }

    function setArtistAddress(
        string calldata sellerId,
        address artistAddress
    ) external onlyOwner {
        bool added = sellerIdToAddresses[sellerId].add(artistAddress);
        if (added) {
            createCollection(sellerId);
        }
    }

    function fetchCollectionAddressOfArtist(
        string calldata sellerId
    ) external view returns (address) {
        return idToArtistCollectionAddress[sellerId];
    }

    function fetchArtistAddressForsellerId(
        string calldata sellerId
    ) external view returns (address[] memory) {
        return sellerIdToAddresses[sellerId].values();
    }

    function purchaseLicense(
        NitrilityCommon.PurchaseData calldata data,
        NitrilityCommon.LicensingType licensingType,
        NitrilityCommon.EventTypes eventType,
        NitrilityCommon.Exclusivity exclusivity
    ) external {
        address collectionAddr = idToArtistCollectionAddress[data.sellerId];
        NitrilityLicense licenseContract = NitrilityLicense(collectionAddr);

        tokenIds.increment();
        uint256 newTokenId = tokenIds.current();

        licenseContract.purchaseLicense(
            newTokenId,
            data.buyerAddr,
            data.newTokenURI,
            data.templateData
        );
        idToSoldLicense[newTokenId] = SoldLicense(
            data.trackId,
            data.newTokenURI,
            data.sellerId,
            data.buyerAddr,
            data.price,
            data.counts,
            licensingType,
            eventType,
            exclusivity
        );

        emit SoldLicenseEvent(newTokenId);
    }

    function burnSoldLicense(uint256 tokenId) external {
        address buyerAddr = idToSoldLicense[tokenId].buyerAddr;
        require(
            buyerAddr == msg.sender || buyerAddr == marketOwner,
            "Only Owner can burn"
        );

        delete idToSoldLicense[tokenId];

        address collectionAddr = idToArtistCollectionAddress[
            idToSoldLicense[tokenId].sellerId
        ];
        NitrilityLicense licenseContract = NitrilityLicense(collectionAddr);
        licenseContract.burnSoldLicense(tokenId);

        emitLicenseburnt(tokenId);
    }

    function reFundOffer(
        address refunder,
        uint256 amount
    ) external onlyAuction {
        if (amount > gasFee) {
            payable(refunder).transfer(amount - gasFee);
        }
    }

    // split the revenues
    function revenueSplits(
        NitrilityCommon.ArtistRevenue[] calldata artistRevenues,
        uint256 revenue
    ) public onlyAuction {
        uint256 totalPercentage = 0;
        uint256 fee = revenue.mul(marketplaceFee).div(1000);
        nitrilityRevenue += fee;
        socialRevenue += fee;

        uint256 restFee = revenue - 2 * fee;
        for (uint256 p = 0; p < artistRevenues.length; p++) {
            idToWithdrawal[artistRevenues[p].sellerId] += restFee
                .mul(artistRevenues[p].percentage)
                .div(10 ** (decimals + 2));
            totalPercentage += artistRevenues[p].percentage;
        }

        require(
            totalPercentage == 10 ** (decimals + 2),
            "Total percentage should be 100%"
        );
    }

    function fetchBalanceOfArtist(
        string calldata sellerId
    ) external view returns (uint256) {
        return idToWithdrawal[sellerId];
    }

    function withdrawMarketRevenue() external onlyOwner {
        require(
            nitrilityRevenue > 0,
            "No funds available for marketplace revenue"
        );
        payable(msg.sender).transfer(nitrilityRevenue);
        nitrilityRevenue = 0;
    }

    function withdrawFund(string calldata sellerId) external {
        require(
            sellerIdToAddresses[sellerId].contains(msg.sender),
            "Only Artist can withdraw"
        );
        require(
            idToWithdrawal[sellerId] > 0,
            "Balance should be larger than 0"
        );
        payable(msg.sender).transfer(idToWithdrawal[sellerId]);
        idToWithdrawal[sellerId] = 0;
    }

    function getChainID() external view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}
