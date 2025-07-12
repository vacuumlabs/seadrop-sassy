// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721SeaDrop} from "./ERC721SeaDrop.sol";

contract Sassy is ERC721SeaDrop {

    // Revealed tokens, and their rarities
    mapping (uint256 => uint8) private revealedTokenIdRarityMapping;

    // TODO: Make these dynamic
    string constant private UNREVEALED_NFT_URI = "https://jade-perfect-gibbon-918.mypinata.cloud/ipfs/bafkreieltelsnuyjlsirn4aexa4yqudfgtpagrbsjbymqtwzjnpx4jo34i";
    string constant private REVEALED_NFT_BASE_URI = "https://jade-perfect-gibbon-918.mypinata.cloud/ipfs/bafybeig3fy55suqgc6d77melvbhwnqhhtrgzjffnbj7wkce6vlqelxfctu/";
    string constant private CONTRACT_URI = "https://jade-perfect-gibbon-918.mypinata.cloud/ipfs/bafkreiedauzkaleiicy5dq7b5rgifw5xlyae5ig6zjt7h2pzcljo27fb2q";

    bool private REVEAL_PHASE_ACTIVE = false;

    constructor(string memory _name, string memory _symbol, address[] memory _allowedSeadrop) 
    ERC721SeaDrop(
        _name,
        _symbol,
        _allowedSeadrop
    ) {}

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (REVEAL_PHASE_ACTIVE) {
            if (revealedTokenIdRarityMapping[tokenId] != 0) {
                return string(abi.encodePacked(REVEALED_NFT_BASE_URI, _toString(revealedTokenIdRarityMapping[tokenId])));
            } else {
                return UNREVEALED_NFT_URI;
            }
        }
        return UNREVEALED_NFT_URI;
    }

    function revealNftNoSignature(uint256 tokenId, uint8 rarity) public {
        require(
            bytes(REVEALED_NFT_BASE_URI).length > 0,
            "Revealed NFT Base URI not set, can't mint currently"
        );
        require(REVEAL_PHASE_ACTIVE, "Reveal phase hasn't started");
        if (!_exists(tokenId)) revert OwnerQueryForNonexistentToken();
        require(rarity <= 11 && rarity > 0, "Rarity should be between 1 to 11.");
        require(
            ownerOf(tokenId) == msg.sender,
            "Only NFT Owner can reveal token"
        );
        require(
            revealedTokenIdRarityMapping[tokenId] == 0,
            "Already revealed token"
        );
        revealedTokenIdRarityMapping[tokenId] = rarity;
    }

    function toggleRevealPhaseActive() public onlyOwner {
        REVEAL_PHASE_ACTIVE = !REVEAL_PHASE_ACTIVE;
    }

    function getRevealPhaseActiveStatus()  public view returns (bool) {
        return REVEAL_PHASE_ACTIVE;
    }

    // function revealNft(
    //     uint16 tokenId,
    //     uint8 rarity,
    //     bytes memory _signature
    // ) public {
    //     require(
    //         bytes(NFT_BASE_URI).length > 0,
    //         "Revealed NFT Base URI not set, can't mint currently"
    //     );
    //     require(REVEAL_PHASE, "Reveal phase hasn't started");
    //     _requireOwned(tokenId);
    //     require(rarity <= 11 && rarity > 0, "Rarity should be between 1 to 11.");
    //     require(
    //         ownerOf(tokenId) == msg.sender,
    //         "Only NFT Owner can reveal token"
    //     );
    //     require(
    //         tokenUnrevealed[tokenId],
    //         "Already revealed token"
    //     );
    //     require(
    //         verifySignature(tokenId, rarity, _signature),
    //         "Invalid Signature"
    //     );
    //     _setTokenURI(tokenId, Strings.toString(rarity));
    //     delete tokenUnrevealed[tokenId];
    //     emit MetadataUpdate(tokenId); // Notifies Opensea to update the metadata with the revealed data
    // }

    // // The burn fee is 10 USDC regardless of tokenIds count
    // function burnNft(uint16[] memory tokenIds) external nonReentrant {
    //     uint256 tokensToBurnCount = tokenIds.length;
    //     require(tokensToBurnCount > 0 && tokensToBurnCount <= 10, "Can only burn 1 - 10 tokens at a time");
    //     require(
    //         IERC20(USDC_CONTRACT_ADDRESS).allowance(
    //             msg.sender,
    //             address(this)
    //         ) >= BURN_FEE,
    //         "Need approval for NFT Collection to spend 10 USDC"
    //     );

    //     require(
    //         IERC20(USDC_CONTRACT_ADDRESS).transferFrom(
    //             msg.sender,
    //             address(this),
    //             BURN_FEE
    //         ),
    //         "Burn Fee payment failed"
    //     );

    //     for (uint256 i = 0; i < tokensToBurnCount; i++) {
    //         uint16 tokenId = tokenIds[i];
    //         _requireOwned(tokenId);
    //         require(
    //             ownerOf(tokenId) == msg.sender,
    //             "Only token Owner can burn the NFT"
    //         );
    //         require(
    //             !tokenUnrevealed[tokenId],
    //             "Cannot burn token before reveal"
    //         );
    //         _burn(tokenId);
    //     }

    //     emit TokensBurn(msg.sender, tokenIds);
    // }

}