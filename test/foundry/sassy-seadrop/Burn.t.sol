pragma solidity ^0.8.17;

import {TestHelper} from "../utils/TestHelper.sol";
import {console} from "forge-std/console.sol";
import "openzeppelin-contracts/utils/Strings.sol";

import {Sassy} from "../../../src/SassySeadrop.sol";
import {SassyShreddersErrorsAndEvents} from "../../../src/SassyErrorsAndEvents.sol";
import {SeaDrop} from "../../../src/SeaDrop.sol";
import {ISeaDrop} from "../../../src/interfaces/ISeaDrop.sol";
import {PublicDrop} from "../../../src/lib/SeaDropStructs.sol";

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC721A} from "ERC721A/IERC721A.sol";

// This contract is not needed to be deployed, this is just to mimic USDC behaviour for testing
contract USDC is ERC20 {
    constructor() ERC20("USDC", "USDC") {
        _mint(msg.sender, 1000 * 1000_000); // 1k USDC
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract BurnNftTest is TestHelper {
    using Strings for string;

    Sassy nftContract;
    USDC usdc;

    address feeRecipient = 0x0000a26b00c1F0DF003000390027140000fAa719;

    bytes signature;

    address user1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address user2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    uint256 pkUser1 = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 pkUser2 = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

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
        vm.deal(user2, 100 ether);

        usdc = new USDC();
        nftContract = new Sassy("Sassy Shredders", "SS", allowedSeadrop, address(usdc));

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
        nftContract.toggleRevealPhaseActive();
        nftContract.setBaseUri("https://new_base_uri.com/");
        nftContract.revealNft(1, 2, signature);
    }

    function test_BurnFailsWhenUsdcNotApproved() public {
        vm.startPrank(user1);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        vm.expectRevert(
            abi.encodeWithSelector(SassyShreddersErrorsAndEvents.InsufficientUSDCApproval.selector, user1, 0)
        );
        nftContract.burnNft(tokenIds);
    }

    function test_BurnFailsWhenInvalidTokenCount() public {
        vm.startPrank(user1);
        usdc.approve(address(nftContract), 10_000_000);

        // Test 1: Empty array should fail
        vm.expectRevert(abi.encodeWithSelector(SassyShreddersErrorsAndEvents.InvalidBurnCount.selector, 0));
        nftContract.burnNft(new uint256[](0));

        // Test 2: Array with 11 elements should fail
        uint256[] memory tokenIds = new uint256[](11);
        for (uint256 i = 0; i < 11; i++) {
            tokenIds[i] = i + 1;
        }

        vm.expectRevert(abi.encodeWithSelector(SassyShreddersErrorsAndEvents.InvalidBurnCount.selector, 11));
        nftContract.burnNft(tokenIds);

        vm.stopPrank();
    }

    function test_BurnFailsIfUsdcPaymentFail() public {
        vm.startPrank(user1);

        // user1 has 1,000 USDC (1,000,000,000 tokens with 6 decimals)
        uint256 initialBalance = usdc.balanceOf(user1); // Should be 1,000,000,000

        // Give allowance to the NFT contract (10 USDC worth)
        usdc.approve(address(nftContract), 10_000_000); // 10 USDC

        usdc.transfer(user2, initialBalance - 5_000_000); // Leave only 5 USDC

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        vm.expectRevert(); // Should use specific error for insufficient balance
        nftContract.burnNft(tokenIds);

        vm.stopPrank();
    }

    function test_BurnFailsIfAnyTokenDoesntExist() public {
        vm.startPrank(user1);

        usdc.approve(address(nftContract), 10_000_000); // 10 USDC

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 2;

        vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector);
        nftContract.burnNft(tokenIds);

        vm.stopPrank();
    }

    function test_BurnFailsIfTokenNotOwned() public {
        vm.startPrank(user2); // User 2 owns token ID 2
        ISeaDrop(seadrop).mintPublic{value: mintPrice}(address(nftContract), feeRecipient, address(0), 1);
        vm.stopPrank();

        // Now user1 tries to burn both tokens (but only owns token 1)
        vm.startPrank(user1);
        usdc.approve(address(nftContract), 10_000_000); // 10 USDC approval
        console.log(usdc.allowance(user1, address(nftContract)));

        uint256[] memory tokenIds = new uint256[](2); // Fixed: array size should be 2
        tokenIds[0] = 1; // user1 owns this
        tokenIds[1] = 2; // user2 owns this - should cause failure

        // Should fail because user1 doesn't own token 2
        vm.expectRevert(abi.encodeWithSelector(SassyShreddersErrorsAndEvents.NotTokenOwner.selector, 2));
        nftContract.burnNft(tokenIds);

        vm.stopPrank();
    }

    function test_BurnFailsIfUnrevealed() public {
        vm.startPrank(user1);
        ISeaDrop(seadrop).mintPublic{value: mintPrice}(address(nftContract), feeRecipient, address(0), 1);
        usdc.approve(address(nftContract), 10_000_000); // 10 USDC approval

        uint256[] memory tokenIds = new uint256[](1); // Fixed: array size should be 2
        tokenIds[0] = 2; // token 2 is not revealed

        vm.expectRevert(abi.encodeWithSelector(SassyShreddersErrorsAndEvents.RarityNotRevealed.selector, 2));
        nftContract.burnNft(tokenIds);
        vm.assertEq(nftContract.getRarityForTokenId(2), 0);
    }

    function test_successfulBurn() public {
        vm.startPrank(user1);
        usdc.approve(address(nftContract), 10_000_000); // 10 USDC approval

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1; // token 2 is not revealed

        nftContract.burnNft(tokenIds);
        vm.assertEq(nftContract.getRarityForTokenId(1), 0);

        vm.expectRevert();
        nftContract.ownerOf(1);
    }
}
