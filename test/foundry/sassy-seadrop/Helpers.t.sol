pragma solidity ^0.8.17;
import {TestHelper} from "../utils/TestHelper.sol";
import {console} from "forge-std/console.sol";
import "openzeppelin-contracts/utils/Strings.sol";
import {Sassy} from "../../../src/SassySeadrop.sol";
import {SassyShreddersErrorsAndEvents} from "../../../src/SassyErrorsAndEvents.sol";
import {SeaDrop} from "../../../src/SeaDrop.sol";
import {ISeaDrop} from "../../../src/interfaces/ISeaDrop.sol";
import { PublicDrop } from "../../../src/lib/SeaDropStructs.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC721A} from "ERC721A/IERC721A.sol";

// This contract is not needed to be deployed, this is just to mimic USDC behaviour for testing
contract USDC is ERC20 {
    constructor() ERC20("USDC", "USDC") {
        _mint(msg.sender, 1000 * 1000 * 1000000); // 1k USDC with 6 decimals
    }
    
    function decimals() public pure override returns(uint8) {
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
        vm.deal(address(nftContract), 100 ether);
        vm.stopPrank();
    }
    
    function test_onlyOwnerCanWithdraw() public {
        // First, let's check who the owner is
        console.log("Contract owner:", nftContract.owner());
        console.log("User1:", user1);
        console.log("User2:", user2);
        
        // Get the actual owner address
        address actualOwner = nftContract.owner();
        
        // USDC Transfer - use direct transfer since user1 has the tokens
        vm.startPrank(user1);
        usdc.transfer(address(nftContract), 50_000_000);
        console.log("USDC balance after transfer:", usdc.balanceOf(address(nftContract)));
        
        // Send some ETH to the contract
        vm.deal(address(nftContract), 1 ether);
        console.log("Contract ETH balance:", address(nftContract).balance);
        vm.stopPrank();
        
        // Withdraw fails for non-owner
        vm.startPrank(user2);
        vm.expectRevert(abi.encodeWithSignature("OnlyOwner()"));
        nftContract.withdrawUSDC();
        vm.expectRevert(abi.encodeWithSignature("OnlyOwner()"));
        nftContract.withdrawEth();
        vm.stopPrank();
        
        // Owner withdraws successfully - use actual owner
        vm.startPrank(actualOwner);
        uint256 usdcBalanceBefore = usdc.balanceOf(actualOwner);
        uint256 ethBalanceBefore = actualOwner.balance;
        
        nftContract.withdrawUSDC();
        nftContract.withdrawEth();
        
        // Verify withdrawals worked
        assertGt(usdc.balanceOf(actualOwner), usdcBalanceBefore, "USDC should be withdrawn");
        assertGt(actualOwner.balance, ethBalanceBefore, "ETH should be withdrawn");
        
        // Add more funds for the new owner to withdraw
        vm.startPrank(user1);
        usdc.transfer(address(nftContract), 25_000_000);
        vm.deal(address(nftContract), 0.5 ether);
        vm.stopPrank();
        
        // Owner changes
        vm.startPrank(actualOwner);
        nftContract.transferOwnership(user2);
        vm.stopPrank();
        
        // New owner can withdraw
        vm.startPrank(user2);
        nftContract.acceptOwnership();
        uint256 user2UsdcBefore = usdc.balanceOf(user2);
        uint256 user2EthBefore = user2.balance;
        
        nftContract.withdrawUSDC();
        nftContract.withdrawEth();
        
        // Verify new owner can withdraw
        assertGt(usdc.balanceOf(user2), user2UsdcBefore, "New owner should be able to withdraw USDC");
        assertGt(user2.balance, user2EthBefore, "New owner should be able to withdraw ETH");
        
        vm.stopPrank();
    }
}