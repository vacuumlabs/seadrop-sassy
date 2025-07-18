// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721SeaDrop} from "./ERC721SeaDrop.sol";
import {SassyShreddersErrorsAndEvents} from "./SassyErrorsAndEvents.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {ECDSA} from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

contract Sassy is ERC721SeaDrop, SassyShreddersErrorsAndEvents {
    using ECDSA for bytes32;

    // Revealed tokens, and their rarities
    mapping(uint256 => uint8) private revealedTokenIdRarityMapping;

    // TODO: Make these dynamic
    string private UNREVEALED_NFT_URI;
    string private REVEALED_NFT_BASE_URI;

    bool private REVEAL_PHASE_ACTIVE = false;
    address private immutable USDC_CONTRACT_ADDRESS;

    address private RARITY_ASSIGNER_ADDRESS;

    uint256 constant BURN_FEE = 10_000_000; // 10 USDC

    constructor(
        string memory _name,
        string memory _symbol,
        address[] memory _allowedSeadrop,
        address _usdcContractAddress
    ) ERC721SeaDrop(_name, _symbol, _allowedSeadrop) {
        USDC_CONTRACT_ADDRESS = _usdcContractAddress;
        RARITY_ASSIGNER_ADDRESS = msg.sender;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return (revealedTokenIdRarityMapping[tokenId] != 0)
            ? string(abi.encodePacked(REVEALED_NFT_BASE_URI, _toString(revealedTokenIdRarityMapping[tokenId])))
            : UNREVEALED_NFT_URI;
    }

    function revealNft(uint256 tokenId, uint8 rarity, bytes calldata signature) public {
        if (!REVEAL_PHASE_ACTIVE) revert RevealPhaseNotActive();
        if (bytes(REVEALED_NFT_BASE_URI).length == 0) revert RevealBaseURINotSet();
        if (!_exists(tokenId)) revert OwnerQueryForNonexistentToken();
        if (rarity > 11 || rarity < 1) revert InvalidRarity(rarity);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
        if (revealedTokenIdRarityMapping[tokenId] != 0) {
            revert RarityAlreadyRevealed(tokenId, revealedTokenIdRarityMapping[tokenId]);
        }
        if (!verifySignature(tokenId, rarity, signature)) revert InvalidECDSASignature();

        // All Checks passed, ready to reveal
        revealedTokenIdRarityMapping[tokenId] = rarity;
        emit TokenRevealed(tokenId, rarity);
        emit BatchMetadataUpdate(tokenId, tokenId);
    }

    function verifySignature(uint256 tokenId, uint8 rarity, bytes calldata signature) public view returns (bool) {
        bytes32 objectHash = keccak256(abi.encodePacked(address(this), block.chainid, tokenId, rarity))
            .toEthSignedMessageHash();
        return objectHash.recover(signature) == RARITY_ASSIGNER_ADDRESS;
    }

    // The burn fee is 10 USDC regardless of tokenIds count
    function burnNft(uint256[] calldata tokenIds) external nonReentrant {
        uint256 tokensToBurnCount = tokenIds.length;
        if (tokensToBurnCount < 1 || tokensToBurnCount > 10) revert InvalidBurnCount(tokensToBurnCount);
        uint256 usdcSpendingAllowance = IERC20(USDC_CONTRACT_ADDRESS).allowance(msg.sender, address(this));

        if (usdcSpendingAllowance < BURN_FEE) revert InsufficientUSDCApproval(msg.sender, usdcSpendingAllowance);

        bool burnFeeSuccessfullyPaid = IERC20(USDC_CONTRACT_ADDRESS).transferFrom(msg.sender, address(this), BURN_FEE);

        if (!burnFeeSuccessfullyPaid) revert USDCPaymentFailed();

        for (uint256 i = 0; i < tokensToBurnCount; i++) {
            uint256 tokenId = tokenIds[i];
            if (!_exists(tokenId)) revert OwnerQueryForNonexistentToken();
            if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
            if (revealedTokenIdRarityMapping[tokenId] == 0) revert RarityNotRevealed(tokenId);
            _burn(tokenId);
            delete revealedTokenIdRarityMapping[tokenId];
        }

        emit TokensBurned(msg.sender, tokenIds);
    }

    // Helper Function for activating reveal phase
    function toggleRevealPhaseActive() public onlyOwner {
        REVEAL_PHASE_ACTIVE = !REVEAL_PHASE_ACTIVE;
    }

    function getRevealPhaseActiveStatus() public view returns (bool) {
        return REVEAL_PHASE_ACTIVE;
    }

    // Rarity Assigner Address Helpers
    function setRarityAssignerAddress(address _newAddress) external onlyOwner {
        RARITY_ASSIGNER_ADDRESS = _newAddress;
    }

    function getRarityAssignerAddress() external view returns (address) {
        return RARITY_ASSIGNER_ADDRESS;
    }

    // ================= URI Helpers =================

    // Set Base URI for revealed assets
    function setRevealedNftBaseUri(string memory _newUri) external onlyOwner {
        REVEALED_NFT_BASE_URI = _newUri;
    }

    function getRevealedNftBaseUri() external view returns (string memory) {
        return REVEALED_NFT_BASE_URI;
    }

    // Change URI for unrevealed NFT object
    function setUnrevealedNftUri(string memory _newUri) external onlyOwner {
        UNREVEALED_NFT_URI = _newUri;
    }

    function getUnrevealedNftUri() external view returns (string memory) {
        return UNREVEALED_NFT_URI;
    }

    function _baseURI() internal view override returns (string memory) {
        return REVEALED_NFT_BASE_URI;
    }

    // Rarity Helpers
    function getRarityForTokenId(uint256 tokenId) public view returns (uint8) {
        return revealedTokenIdRarityMapping[tokenId];
    }

    // =================== WITHDRAW FUNCTIONS ===================

    // Owner can withdraw USDC from the contract via this function
    function withdrawUSDC() external onlyOwner nonReentrant {
        uint256 allUSDC = IERC20(USDC_CONTRACT_ADDRESS).balanceOf(address(this));
        IERC20(USDC_CONTRACT_ADDRESS).transfer(msg.sender, allUSDC);
    }

    // Withdraw ETH Sent to this contract
    function withdrawEth() external onlyOwner nonReentrant {
        (bool success,) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Failed to withdraw ETH");
    }

    // Withdraw any other ERC20 tokens (apart from USDC) sent to contract accidentally
    function withdrawErc20(address _tokenAddress) external onlyOwner nonReentrant {
        require(_tokenAddress != USDC_CONTRACT_ADDRESS, "Cannot withdraw USDC from this function");
        uint256 allTokens = IERC20(_tokenAddress).balanceOf(address(this));
        IERC20(_tokenAddress).transfer(msg.sender, allTokens);
    }

    receive() external payable {}
}
