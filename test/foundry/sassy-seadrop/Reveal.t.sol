pragma solidity ^0.8.17;

import {TestHelper} from "../utils/TestHelper.sol";
import {console} from "forge-std/console.sol";
import "openzeppelin-contracts/utils/Strings.sol";

import {Sassy} from "../../../src/SassySeadrop.sol";
import {SassyShreddersErrorsAndEvents} from "../../../src/SassyErrorsAndEvents.sol";
import {SeaDrop} from "../../../src/SeaDrop.sol";
import {ISeaDrop} from "../../../src/interfaces/ISeaDrop.sol";
import {PublicDrop} from "../../../src/lib/SeaDropStructs.sol";
import {IERC721A} from "ERC721A/IERC721A.sol";

contract RevealNftTest is TestHelper {
    using Strings for string;

    Sassy nftContract;

    address feeRecipient = 0x0000a26b00c1F0DF003000390027140000fAa719;

    bytes signature;

    address user1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address user2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    uint256 pkUser1 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 pkUser2 = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    address USDC_CONTRACT_ADDRESS = vm.envAddress("USDC_ADDRESS");
    uint256 constant CHAIN_ID = 31337;
    uint256 constant TOKEN_ID = 1;
    uint8 constant RARITY = 5;

    uint16 feeBps = 300; // 3% Secondary Sale Fee
    uint80 mintPrice = 0.0001 ether;
    uint16 maxTotalMintableByWallet = 3;

    function setUp() public {
        address[] memory allowedSeadrop = new address[](1);
        allowedSeadrop[0] = address(seadrop);
        // Deploy contract

        vm.startPrank(user1);
        vm.deal(user1, 100 ether);

        nftContract = new Sassy("Sassy Shredders", "SS", allowedSeadrop, USDC_CONTRACT_ADDRESS);

        nftContract.setMaxSupply(1000);

        // Set the creator payout address.
        nftContract.updateCreatorPayoutAddress(address(seadrop), creator);
        nftContract.updateAllowedFeeRecipient(address(seadrop), feeRecipient, true);

        nftContract.updatePublicDrop(
            address(seadrop),
            PublicDrop(
                mintPrice,
                uint48(block.timestamp), // start time
                uint48(block.timestamp) + 100, // end time (3 days)
                maxTotalMintableByWallet,
                feeBps,
                true
            )
        );
        ISeaDrop(seadrop).mintPublic{value: mintPrice}(address(nftContract), feeRecipient, address(0), 1);

        // Create signature
        bytes32 messageHash = keccak256(abi.encodePacked(address(nftContract), block.chainid, uint256(1), uint8(2)));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        // Sign the message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkUser1, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);
    }

    function test_RevealFailsIfRevealStageInactive() public {
        vm.expectRevert(SassyShreddersErrorsAndEvents.RevealPhaseNotActive.selector);
        nftContract.revealNft(1, 5, signature);
    }

    function test_RevealFailsIfRevealedUriNotSet() public {
        vm.startPrank(user1);
        nftContract.toggleRevealPhaseActive();
        vm.expectRevert(SassyShreddersErrorsAndEvents.RevealBaseURINotSet.selector);
        nftContract.revealNft(1, 5, signature);
    }

    function test_RevealFailsIfTokenNotOwned() public {
        vm.startPrank(user1);
        nftContract.toggleRevealPhaseActive();
        nftContract.setBaseUri("https://new_base_uri.com/");

        vm.startPrank(user2);
        vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector);
        nftContract.revealNft(4, 5, signature);
    }

    function test_RevealFailsWhenCallerNotOwner() public {
        vm.startPrank(user1);
        nftContract.toggleRevealPhaseActive();
        nftContract.setBaseUri("https://new_base_uri.com/");

        vm.startPrank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                SassyShreddersErrorsAndEvents.NotTokenOwner.selector,
                1 // the tokenId parameter
            )
        );
        nftContract.revealNft(1, 5, signature);
    }

    function test_RevealFailsIfInvalidRarityInvalidTokenId() public {
        vm.startPrank(user1);
        nftContract.toggleRevealPhaseActive();
        nftContract.setBaseUri("https://new_base_uri.com/");

        vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector);
        nftContract.revealNft(5051, 5, signature);
        vm.expectRevert(abi.encodeWithSelector(SassyShreddersErrorsAndEvents.InvalidRarity.selector, 12));

        nftContract.revealNft(1, 12, signature);
    }

    function test_RevealFailsIfAlreadyRevealed() public {
        vm.startPrank(user1);
        nftContract.toggleRevealPhaseActive();
        nftContract.setBaseUri("https://new_base_uri.com/");

        // Directly storing a rarity in the memory for key 1 = value 1 on slot 19
        // Slots can be found using forge inspect contract-name storage-layout
        vm.store(address(nftContract), keccak256(abi.encode(1, 19)), bytes32(uint256(1)));

        vm.expectRevert(abi.encodeWithSelector(SassyShreddersErrorsAndEvents.RarityAlreadyRevealed.selector, 1, 1));

        nftContract.revealNft(1, 2, signature);
    }

    function test_RevealSuccessfulForCorrectSignature() public {
        vm.startPrank(user1);
        nftContract.toggleRevealPhaseActive();
        nftContract.setBaseUri("https://new_base_uri.com/");
        vm.assertEq(nftContract.getRarityForTokenId(1), 0);
        nftContract.revealNft(1, 2, signature);
        vm.assertEq(nftContract.getRarityForTokenId(1), 2);
        vm.assertEq(nftContract.tokenURI(1), "https://new_base_uri.com/2");
        vm.assertEq(nftContract.tokenURI(2), nftContract.getUnrevealedNftUri());
    }

    function test_RevealFailsForSignatureByBadActor() public {
        vm.startPrank(user1);
        nftContract.toggleRevealPhaseActive();
        nftContract.setBaseUri("https://new_base_uri.com/");

        bytes32 messageHash = keccak256(abi.encodePacked(address(nftContract), block.chainid, uint256(1), uint8(2)));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        // Sign the message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkUser2, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        vm.startPrank(user1);
        vm.expectRevert(SassyShreddersErrorsAndEvents.InvalidECDSASignature.selector);
        nftContract.revealNft(1, 2, signature);
    }

    function test_RevealFailsForSignatureForDifferentTokenOrRarity() public {
        vm.startPrank(user1);
        nftContract.toggleRevealPhaseActive();
        nftContract.setBaseUri("https://new_base_uri.com/");

        // Second NFT Owned by owner
        ISeaDrop(seadrop).mintPublic{value: mintPrice}(address(nftContract), feeRecipient, address(0), 1);

        vm.expectRevert(SassyShreddersErrorsAndEvents.InvalidECDSASignature.selector);
        nftContract.revealNft(2, 1, signature);

        vm.expectRevert(SassyShreddersErrorsAndEvents.InvalidECDSASignature.selector);
        nftContract.revealNft(1, 11, signature);
    }
}
