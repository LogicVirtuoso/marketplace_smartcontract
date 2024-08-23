// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "../NitrilityCommon.sol";

interface INitrilityFactory {
    function fetchArtistAddressForsellerId(
        string calldata sellerId
    ) external view returns (address[] memory);

    function fetchCollectionAddressOfArtist(
        string calldata sellerId
    ) external view returns (address);

    function purchaseLicense(
        NitrilityCommon.PurchaseData calldata data,
        NitrilityCommon.LicensingType licensingType,
        NitrilityCommon.EventTypes eventType,
        NitrilityCommon.Exclusivity exclusivity
    ) external;

    function revenueSplits(
        NitrilityCommon.ArtistRevenue[] calldata artistRevenues,
        uint256 revenue
    ) external;

    function reFundOffer(address refunder, uint256 offerPrice) external;
}
