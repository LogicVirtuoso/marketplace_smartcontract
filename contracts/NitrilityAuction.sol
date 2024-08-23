// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./utils/SafeMath.sol";
import "./utils/Counters.sol";
import "./NitrilityCommon.sol";
import "./interfaces/INitrilityFactory.sol";

contract NitrilityAuction is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    address public marketOwner;
    address public nitrilityFactory;
    Counters.Counter private offerIds;

    EnumerableSet.UintSet offerSet;

    enum PurchaseType {
        Business,
        Personal
    }

    struct Metadata {
        PurchaseType purchaseType;
        uint256 exclusiveTime;
        string governingLaw;
        string sellerId;
        string usageNotes;
        string advertisementTitle;
        string productDescription;
        string contentDescription;
        string intendedPlatforms;
        string additionalInfo;
    }

    struct LicensesData {
        string discountCode;
        string newTokenURI;
        string trackId;
        uint256 offerPrice;
        uint256 offerDuration;
        uint256 counts;
        NitrilityCommon.LicensingType licensingType;
        NitrilityCommon.Exclusivity exclusivity;
        NitrilityCommon.TemplateType templateData;
        Metadata metadata;
    }

    struct OfferData {
        uint256 offerId;
        string trackId;
        address buyerAddr;
        uint256 offerPrice;
        uint256 offerDuration;
        string tokenURI;
        NitrilityCommon.EventTypes eventType;
        NitrilityCommon.LicensingType licensingType;
        NitrilityCommon.Exclusivity exclusivity;
        uint256 counts;
        uint256 purchaseTime;
        Metadata metadata;
    }

    event OfferEvent(
        uint256 offerId,
        uint256 offerPrice,
        uint256 offerDuration,
        NitrilityCommon.EventTypes eventType,
        bool isSeller
    );

    // track id => offer id
    mapping(string => EnumerableSet.UintSet) offerIdsOfLicense;
    mapping(address => EnumerableSet.UintSet) offerIdsOfBuyer;

    constructor() Ownable(msg.sender) ReentrancyGuard() {
        marketOwner = msg.sender;
    }

    modifier onlyAuthorizedCaller() {
        require(
            msg.sender == owner() || msg.sender == marketOwner,
            "Unauthorized caller"
        );
        _;
    }

    // offer
    mapping(uint256 => OfferData) private idToOffer;

    function setMarketOwner(
        address _marketOwner
    ) external onlyAuthorizedCaller {
        marketOwner = _marketOwner;
    }

    function setFactory(
        address _nitrilityFactory
    ) external onlyAuthorizedCaller {
        nitrilityFactory = _nitrilityFactory;
    }

    // Check if the target address is in the array of addresses
    function containsAddress(
        address[] calldata array,
        address target
    ) internal pure returns (bool) {
        // Iterate through the array
        for (uint256 i = 0; i < array.length; i++) {
            // Check if the current element matches the target address
            if (array[i] == target) {
                return true;
            }
        }
        // Return false if the target address is not found
        return false;
    }

    // Function to check if the license type is valid
    function checkLicenseValid(
        NitrilityCommon.TemplateType calldata templateType
    ) internal view {
        require(
            templateType.listed == NitrilityCommon.ListingStatus.Listed,
            "License type not listed"
        );

        require(
            (!templateType.infiniteSupply && templateType.totalSupply > 0) ||
                templateType.infiniteSupply,
            "Total supply is zero"
        );

        if (!templateType.infiniteListingDuration) {
            uint256 curTime = block.timestamp * 1000;
            require(
                templateType.listingStartTime <= curTime,
                "License has not started yet"
            );
            require(
                templateType.listingEndTime >= curTime,
                "License has expired"
            );
        }
    }

    function calculateTotalPrice(
        LicensesData[] calldata licenseDatas
    ) public pure returns (uint256) {
        uint256 totalPrice = 0;

        for (uint256 i = 0; i < licenseDatas.length; i++) {
            uint256 percentage = 0;
            uint256 licensePrice = 0;
            NitrilityCommon.TemplateType memory templateData = licenseDatas[i]
                .templateData;
            require(
                templateData.exclusivity == licenseDatas[i].exclusivity ||
                    templateData.exclusivity == NitrilityCommon.Exclusivity.Both
            );

            if (
                licenseDatas[i].licensingType ==
                NitrilityCommon.LicensingType.Creator
            ) {
                // Iterate through discount codes to check for applicable discounts
                if (
                    keccak256(bytes(licenseDatas[i].discountCode)) ==
                    keccak256(bytes(templateData.discountCode.code))
                ) {
                    percentage = templateData.discountCode.percentage;
                    require(percentage < 100, "InValid Discount Code");
                    break;
                }
                if (
                    templateData.listingFormatValue ==
                    NitrilityCommon.ListingType.OnlyPrice
                ) {
                    if (
                        licenseDatas[i].exclusivity ==
                        NitrilityCommon.Exclusivity.Exclusive
                    ) {
                        licensePrice = templateData.sPrice;
                    } else {
                        licensePrice = templateData.fPrice;
                    }
                } else {
                    licensePrice = licenseDatas[i].offerPrice;
                }
            } else {
                licensePrice = licenseDatas[i].offerPrice;
            }
            // Calculate total price based on license price and discount percentage
            totalPrice +=
                (licensePrice * (100 - percentage) * licenseDatas[i].counts) /
                100;
        }

        return totalPrice;
    }

    // auction part
    // make the offer on creator or media sync license
    function createOfferData(
        string calldata trackId,
        uint256 offerDuration,
        string calldata tokenURI,
        NitrilityCommon.LicensingType licensingType,
        NitrilityCommon.Exclusivity exclusivity,
        address buyerAddr,
        uint256 offerPrice,
        uint256 counts,
        Metadata calldata metadata
    ) public {
        // Check if the offer already exists for the given conditions
        require(
            !offerExists(trackId, licensingType, exclusivity),
            "Already placed a bid on this license"
        );

        // Increment offerIds
        offerIds.increment();
        uint256 currentOfferId = offerIds.current();

        // Add currentOfferId to offerSet
        offerSet.add(currentOfferId);

        // Create OfferData struct
        idToOffer[currentOfferId] = OfferData(
            currentOfferId,
            trackId,
            buyerAddr,
            offerPrice,
            offerDuration,
            tokenURI,
            NitrilityCommon.EventTypes.OfferPlaced,
            licensingType,
            exclusivity,
            counts,
            block.timestamp,
            metadata
        );

        // Emit OfferEvent
        emit OfferEvent(
            currentOfferId,
            offerPrice,
            offerDuration,
            NitrilityCommon.EventTypes.OfferPlaced,
            false
        );

        // Update offerIdsOfLicense and offerIdsOfBuyer mappings
        offerIdsOfLicense[trackId].add(currentOfferId);
        offerIdsOfBuyer[buyerAddr].add(currentOfferId);
    }

    // Function to check if an offer already exists for the given conditions
    function offerExists(
        string calldata trackId,
        NitrilityCommon.LicensingType licensingType,
        NitrilityCommon.Exclusivity exclusivity
    ) internal view returns (bool) {
        uint256 offerCount = offerIdsOfBuyer[msg.sender].length();
        for (uint256 i = 0; i < offerCount; i++) {
            uint256 offerId = offerIdsOfBuyer[msg.sender].at(i);
            OfferData storage existingOffer = idToOffer[offerId];
            if (
                compareStrings(existingOffer.trackId, trackId) &&
                existingOffer.eventType ==
                NitrilityCommon.EventTypes.OfferPlaced &&
                existingOffer.licensingType == licensingType &&
                existingOffer.exclusivity == exclusivity
            ) {
                return true;
            }
        }
        return false;
    }

    function placeOffer(
        string calldata trackId,
        uint256 offerDuration,
        string calldata tokenURI,
        NitrilityCommon.LicensingType licensingType,
        NitrilityCommon.Exclusivity exclusivity,
        Metadata calldata metadata
    ) public payable {
        createOfferData(
            trackId,
            offerDuration,
            tokenURI,
            licensingType,
            exclusivity,
            msg.sender,
            msg.value,
            1,
            metadata
        );
        payable(nitrilityFactory).transfer(msg.value);
    }

    // edit offer on buyer side
    function editOffer(
        uint256 offerId,
        uint256 offerPrice,
        uint256 offerDuration,
        NitrilityCommon.EventTypes eventType
    ) public payable {
        OfferData storage offerData = idToOffer[offerId];
        require(
            eventType == NitrilityCommon.EventTypes.OfferEdited ||
                eventType == NitrilityCommon.EventTypes.OfferWithdrawn,
            "You can just edit or withdraw the offer"
        );

        require(
            offerData.buyerAddr == msg.sender,
            "Authorization: You cant edit this offer"
        );

        if (offerPrice < offerData.offerPrice) {
            // INitrilityFactory(nitrilityFactory).reFundOffer(
            //     msg.sender,
            //     offerData.offerPrice - offerPrice
            // );
        } else {
            require(
                offerPrice <= offerData.offerPrice + msg.value,
                "You should add more funds to edit this offer"
            );
            payable(nitrilityFactory).transfer(msg.value);
        }

        offerData.offerPrice = offerPrice;
        offerData.offerDuration = offerDuration;

        emit OfferEvent(offerId, offerPrice, offerDuration, eventType, false);
    }

    // accept the the upcoming offer on seller side
    function acceptOffer(
        uint256 offerId,
        string calldata sellerId,
        NitrilityCommon.TemplateType calldata templateData,
        NitrilityCommon.ArtistRevenue[] calldata artistRevenues
    ) public payable {
        OfferData storage offerData = idToOffer[offerId];
        require(
            msg.sender == offerData.buyerAddr || msg.sender == marketOwner,
            "Authorization: You cant accept this offer"
        );
        bool isSeller;
        if (msg.sender == offerData.buyerAddr) {
            isSeller = false;
        } else {
            isSeller = true;
        }

        require(
            offerData.eventType != NitrilityCommon.EventTypes.OfferRejected &&
                offerData.eventType !=
                NitrilityCommon.EventTypes.OfferWithdrawn &&
                offerData.eventType != NitrilityCommon.EventTypes.OfferAccepted,
            "Invalid Sale Type"
        );

        uint256 offerPrice;
        if (offerData.exclusivity == NitrilityCommon.Exclusivity.NonExclusive) {
            offerPrice = templateData.fPrice;
        } else {
            offerPrice = templateData.sPrice;
        }

        if (offerPrice < offerData.offerPrice) {
            INitrilityFactory(nitrilityFactory).reFundOffer(
                msg.sender,
                offerData.offerPrice - offerPrice
            );
        } else {
            require(
                offerPrice <= offerData.offerPrice + msg.value,
                "You should add more funds to accept this offer"
            );
            payable(nitrilityFactory).transfer(msg.value);
        }

        offerData.eventType = NitrilityCommon.EventTypes.OfferAccepted;

        NitrilityCommon.PurchaseData memory purchaseData = NitrilityCommon
            .PurchaseData(
                offerData.trackId,
                sellerId,
                offerData.tokenURI,
                offerData.buyerAddr,
                templateData,
                offerData.offerPrice,
                offerData.counts
            );

        INitrilityFactory(nitrilityFactory).purchaseLicense(
            purchaseData,
            offerData.licensingType,
            NitrilityCommon.EventTypes.OfferAccepted,
            offerData.exclusivity
        );
        INitrilityFactory(nitrilityFactory).revenueSplits(
            artistRevenues,
            offerData.offerPrice
        );

        emit OfferEvent(
            offerId,
            offerData.offerPrice,
            offerData.offerDuration,
            NitrilityCommon.EventTypes.OfferAccepted,
            isSeller
        );
    }

    // reject the offer
    function rejectOffer(uint256 offerId) external {
        bool isSeller;
        OfferData storage offerData = idToOffer[offerId];
        require(
            msg.sender == offerData.buyerAddr || msg.sender == marketOwner,
            "Authorization: You cant reject this offer"
        );

        if (msg.sender == offerData.buyerAddr) {
            isSeller = false;
        } else {
            isSeller = true;
        }

        require(
            offerData.eventType != NitrilityCommon.EventTypes.OfferRejected &&
                offerData.eventType !=
                NitrilityCommon.EventTypes.OfferWithdrawn &&
                offerData.eventType != NitrilityCommon.EventTypes.OfferAccepted,
            "Invalid Sale Type"
        );

        NitrilityCommon.EventTypes eventType;
        eventType = NitrilityCommon.EventTypes.OfferRejected;

        // Update the event type of the offer
        offerData.eventType = eventType;

        // Emit the offer event
        emit OfferEvent(
            offerId,
            offerData.offerPrice,
            offerData.offerDuration,
            NitrilityCommon.EventTypes.OfferRejected,
            isSeller
        );

        // Refund the offer price to the buyer
        INitrilityFactory(nitrilityFactory).reFundOffer(
            offerData.buyerAddr,
            offerData.offerPrice
        );
    }

    // fetch all offers on marketplace
    // function fetchAllOffers() public view returns (OfferData[] memory) {
    //     uint256 itemCount = offerSet.length();
    //     OfferData[] memory offers = new OfferData[](itemCount);
    //     for (uint256 i = 0; i < itemCount; i++) {
    //         uint256 offerId = offerSet.at(i);
    //         offers[i] = idToOffer[offerId];
    //     }
    //     return offers;
    // }

    // // Fetch the offers by list ID on the seller side
    // function fetchOffersOfSeller(
    //     string calldata trackId,
    //     NitrilityCommon.LicensingType licensingType
    // ) public view returns (OfferData[] memory) {
    //     uint256 itemCount = offerIdsOfLicense[trackId].length();
    //     OfferData[] memory offers = new OfferData[](itemCount);
    //     uint256 currentIndex = 0;

    //     // Iterate over the offer IDs associated with the track ID
    //     for (uint256 i = 0; i < itemCount; i++) {
    //         uint256 offerId = offerIdsOfLicense[trackId].at(i);
    //         OfferData storage currentItem = idToOffer[offerId];

    //         // Filter offers by licensing type and event type
    //         if (
    //             currentItem.eventType ==
    //             NitrilityCommon.EventTypes.OfferPlaced &&
    //             currentItem.licensingType == licensingType
    //         ) {
    //             offers[currentIndex] = currentItem;
    //             currentIndex++;
    //         }
    //     }

    //     // Resize the offers array to remove unused slots
    //     assembly {
    //         mstore(offers, currentIndex)
    //     }

    //     return offers;
    // }

    // // fetch the offers by list id on seller side
    // function fetchAllOffersOfSeller(
    //     string memory trackId
    // ) public view returns (OfferData[] memory) {
    //     uint256 itemCount = offerIdsOfLicense[trackId].length();
    //     OfferData[] memory offers = new OfferData[](itemCount);
    //     uint256 currentIndex = 0;
    //     for (uint256 i = 0; i < itemCount; i++) {
    //         uint256 offerId = offerIdsOfLicense[trackId].at(i);
    //         OfferData storage currentItem = idToOffer[offerId];
    //         if (
    //             currentItem.eventType == NitrilityCommon.EventTypes.OfferPlaced
    //         ) {
    //             offers[currentIndex] = currentItem;
    //             currentIndex++;
    //         }
    //     }
    //     return offers;
    // }

    // // fetch offer by licensing type and listed id on buyer side
    // function fetchOfferOfBuyer(
    //     address buyerAddr,
    //     string calldata trackId,
    //     NitrilityCommon.LicensingType licensingType
    // ) public view returns (OfferData[] memory) {
    //     uint256 bidCount = offerIdsOfBuyer[buyerAddr].length();
    //     OfferData[] memory offers = new OfferData[](bidCount);
    //     uint256 currentIndex = 0;
    //     for (uint256 i = 0; i < bidCount; i++) {
    //         uint256 offerId = offerIdsOfBuyer[buyerAddr].at(i);
    //         OfferData storage currentItem = idToOffer[offerId];

    //         if (
    //             currentItem.licensingType == licensingType &&
    //             currentItem.eventType ==
    //             NitrilityCommon.EventTypes.OfferPlaced &&
    //             compareStrings(currentItem.trackId, trackId)
    //         ) {
    //             offers[currentIndex] = currentItem;
    //             currentIndex++;
    //         }
    //     }
    //     return offers;
    // }

    // // fetch all offers by licensing type on buyer side
    // function fetchAllOffersOfBuyer(
    //     address buyerAddr,
    //     NitrilityCommon.LicensingType licensingType
    // ) public view returns (OfferData[] memory) {
    //     uint256 bidCount = offerIdsOfBuyer[buyerAddr].length();
    //     OfferData[] memory offers = new OfferData[](bidCount);
    //     uint256 currentIndex = 0;
    //     for (uint256 i = 0; i < bidCount; i++) {
    //         uint256 offerId = offerIdsOfBuyer[buyerAddr].at(i);
    //         OfferData storage currentItem = idToOffer[offerId];

    //         if (
    //             currentItem.eventType ==
    //             NitrilityCommon.EventTypes.OfferPlaced &&
    //             currentItem.licensingType == licensingType
    //         ) {
    //             offers[currentIndex++] = currentItem;
    //         }
    //     }
    //     return offers;
    // }

    // accept the the upcoming offer on seller side
    function fetchCurrentOfferPrice(
        uint256 offerId
    ) public view returns (uint256) {
        OfferData memory offerData = idToOffer[offerId];
        return offerData.offerPrice;
    }

    // purchase multi licensing types
    function purchaseLicenses(
        LicensesData[] calldata licenseDatas
    ) public payable {
        uint256 totalPrice = calculateTotalPrice(licenseDatas);

        // Check if total price matches the sent value
        require(
            totalPrice <= msg.value,
            "Total Price should be larger than the amount of the market price"
        );

        // Transfer total price to the factory
        payable(nitrilityFactory).transfer(msg.value);

        for (uint256 i = 0; i < licenseDatas.length; i++) {
            LicensesData calldata currentLicense = licenseDatas[i];
            NitrilityCommon.TemplateType calldata templateData = currentLicense
                .templateData;

            // Check validity of the license
            checkLicenseValid(templateData);

            // Determine the price based on license type and template
            uint256 licensePrice;
            if (
                currentLicense.licensingType ==
                NitrilityCommon.LicensingType.Creator
            ) {
                if (
                    templateData.listingFormatValue ==
                    NitrilityCommon.ListingType.OnlyPrice
                ) {
                    licensePrice = (currentLicense.exclusivity ==
                        NitrilityCommon.Exclusivity.NonExclusive)
                        ? templateData.fPrice
                        : templateData.sPrice;
                } else {
                    licensePrice = currentLicense.offerPrice;
                }
            } else {
                licensePrice = currentLicense.offerPrice;
            }

            // Purchase or create offer based on listing format
            if (
                templateData.listingFormatValue ==
                NitrilityCommon.ListingType.OnlyPrice
            ) {
                NitrilityCommon.PurchaseData
                    memory purchaseData = NitrilityCommon.PurchaseData(
                        currentLicense.trackId,
                        currentLicense.metadata.sellerId,
                        currentLicense.newTokenURI,
                        msg.sender,
                        templateData,
                        licensePrice,
                        currentLicense.counts
                    );

                INitrilityFactory(nitrilityFactory).purchaseLicense(
                    purchaseData,
                    currentLicense.licensingType,
                    NitrilityCommon.EventTypes.Purchased,
                    currentLicense.exclusivity
                );
            } else {
                createOfferData(
                    currentLicense.trackId,
                    currentLicense.offerDuration,
                    currentLicense.newTokenURI,
                    currentLicense.licensingType,
                    currentLicense.exclusivity,
                    msg.sender,
                    licensePrice,
                    currentLicense.counts,
                    currentLicense.metadata
                );
            }
        }
    }

    // Function to compare two strings (one in storage, one in calldata)
    function compareStrings(
        string storage a,
        string calldata b
    ) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
