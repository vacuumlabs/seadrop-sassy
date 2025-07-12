// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface SassyShreddersErrorsAndEvents {
    /// @dev When reveal phase hasn't started
    error RevealPhaseNotActive();

    error NotTokenOwner(uint256 tokenId);
    error InvalidTokenId(uint256 tokenId);
    error InvalidRarity(uint256 rarity);
    error RarityAlreadyRevealed(uint256 tokenId, uint8 rarity);
    error RarityNotRevealed(uint256 tokenId);

    error RevealBaseURINotSet();
    error InvalidECDSASignature();


    error InvalidBurnCount(uint256 tokensCount);
    error InsufficientUSDCApproval(address userAddress, uint256 amount);
    error USDCPaymentFailed();

    event TokensBurn(address userAddress, uint256[] tokenIds);
    event TokenRevealed(uint256 tokenId, uint8 rarity);
}