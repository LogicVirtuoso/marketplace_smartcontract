// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "./NitrilityCommon.sol";
import "./interfaces/INitrilityFactory.sol";
import "hardhat/console.sol";

contract NitrilityLicense is ERC721URIStorage, EIP712 {
    string private constant SIGNING_DOMAIN = "nitrility-license-marketplace";
    string private constant SIGNATURE_VERSION = "1";

    address public _nitrilityFactory;
    string public _sellerId;

    constructor(
        address nitrilityFactory,
        string memory sellerId
    )
        ERC721("Nitrility License", "NLicense")
        EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION)
    {
        _nitrilityFactory = nitrilityFactory;
        _sellerId = sellerId;
    }

    // check if the signer is specific seller
    function isValid(address signer) public view returns (bool) {
        bool bValid = false;
        address[] memory addresses = INitrilityFactory(_nitrilityFactory)
            .fetchArtistAddressForsellerId(_sellerId);
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == signer) {
                bValid = true;
            }
        }
        return bValid;
    }

    /// @notice Redeems an License for an actual License, creating it in the process.
    /// @param buyerAddr The address of the account which will receive the License upon success.
    /// @param template A signed License that describes the License to be redeemed.
    function purchaseLicense(
        uint256 tokenId,
        address buyerAddr,
        string memory newTokenUri,
        NitrilityCommon.TemplateType memory template
    ) public payable {
        // make sure signature is valid and get the address of the signer
        address signer = _verify(template);

        // make sure that the signer is authorized to mint Licenses
        require(isValid(signer), "Signature invalid or unauthorized");

        // first assign the token to the signer, to establish provenance on-chain
        _mint(buyerAddr, tokenId);
        _setTokenURI(tokenId, newTokenUri);
    }

    function hashDiscountCode(
        NitrilityCommon.DiscountCode memory discountcode
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "DiscountCode(string name,string code,uint256 discountType,uint256 percentage,uint256 fixedAmount,bool infinite,uint256 endTime,bool actived)"
                    ),
                    keccak256(bytes(discountcode.name)),
                    keccak256(bytes(discountcode.code)),
                    discountcode.discountType,
                    discountcode.percentage,
                    discountcode.fixedAmount,
                    discountcode.infinite,
                    discountcode.endTime,
                    discountcode.actived
                )
            );
    }

    /// @notice Returns a hash of the given TemplateData, prepared using EIP712 typed data hashing rules.
    /// @param template An TemplateData to hash.
    function _hash(
        NitrilityCommon.TemplateType memory template
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "TemplateType(uint256 fPrice,uint256 sPrice,uint256 tPrice,uint256 listingFormatValue,bool infiniteSupply,bool infiniteListingDuration,bool infiniteExclusiveDuration,uint256 exclusivity,uint256 listingStartTime,uint256 listingEndTime,uint256 exclusiveEndTime,DiscountCode discountCode,uint256 listed)DiscountCode(string name,string code,uint256 discountType,uint256 percentage,uint256 fixedAmount,bool infinite,uint256 endTime,bool actived)"
                        ),
                        template.fPrice,
                        template.sPrice,
                        template.tPrice,
                        template.listingFormatValue,
                        template.infiniteSupply,
                        template.infiniteListingDuration,
                        template.infiniteExclusiveDuration,
                        template.exclusivity,
                        template.listingStartTime,
                        template.listingEndTime,
                        template.exclusiveEndTime,
                        hashDiscountCode(template.discountCode),
                        template.listed
                    )
                )
            );
    }

    /// @notice Verifies the signature for a given License, returning the address of the signer.
    /// @dev Will revert if the signature is invalid. Does not verify that the signer is authorized to mint Licenses.
    /// @param template An License describing an unminted License.
    function _verify(
        NitrilityCommon.TemplateType memory template
    ) public view returns (address) {
        bytes32 digest = _hash(template);
        return ECDSA.recover(digest, template.signature);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // transfer license to buyer
    function transferLicense(
        address receiver,
        uint256 tokenId,
        address sender
    ) external payable {
        _transfer(sender, receiver, tokenId);
    }

    /* Burns the expired sold license */
    function burnSoldLicense(uint256 tokenId) public {
        _burn(tokenId);
    }
}