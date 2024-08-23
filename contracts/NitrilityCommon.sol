// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract NitrilityCommon {
    // License listing status
    enum ListingStatus {
        NonListed,
        Listed,
        UnListed,
        Expired,
        Exclusived
    }

    // Showcase Offer Status
    enum ReviewStatus {
        Pending,
        Approved,
        Rejected,
        Deleted
    }

    enum EventTypes {
        Purchased,
        OfferPlaced,
        OfferAccepted,
        OfferRejected,
        OfferWithdrawn,
        OfferEdited,
        OfferExpired
    }

    enum Exclusivity {
        NonExclusive,
        Exclusive,
        Both,
        None
    }

    // Listing Type
    enum ListingType {
        OnlyBid,
        OnlyPrice,
        BidAndPrice
    }

    // Licensing Type
    enum LicensingType {
        Creator,
        Advertisement,
        TvSeries,
        Movie,
        VideoGame,
        AiTraining
    }

    // Artist Revenue
    struct ArtistRevenue {
        string sellerId;
        string sellerName;
        uint256 percentage;
        bool isAdmin;
        ReviewStatus status;
    }

    // Discount Type
    enum DiscountType {
        PercentageOff,
        FixedAmountOff
    }

    // Discount Code
    struct DiscountCode {
        string name;
        string code;
        DiscountType discountType;
        uint256 percentage;
        uint256 fixedAmount;
        bool infinite;
        uint256 endTime;
        bool actived;
    }

    // Define the structure of creator, media licenses
    struct TemplateType {
        uint256 fPrice;
        uint256 sPrice;
        uint256 tPrice;
        ListingType listingFormatValue;
        uint256 totalSupply;
        bool infiniteSupply;
        bool infiniteListingDuration;
        bool infiniteExclusiveDuration;
        Exclusivity exclusivity;
        uint256 listingStartTime;
        uint256 listingEndTime;
        uint256 exclusiveEndTime;
        DiscountCode discountCode;
        ListingStatus listed;
        bytes signature;
    }

    // Lazy Minting Data
    struct License {
        string trackId;
        string sellerId;
        string tokenURI;
        TemplateType creator;
        TemplateType advertisement;
        TemplateType tvSeries;
        TemplateType movie;
        TemplateType videoGame;
        TemplateType aiTraining;
    }

    struct PurchaseData {
        string trackId;
        string sellerId;
        string newTokenURI;
        address buyerAddr;
        NitrilityCommon.TemplateType templateData;
        uint256 price;
        uint256 counts;
    }
}
