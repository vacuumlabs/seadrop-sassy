// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import { Sassy } from "../src/SassySeadrop.sol";

import { ISeaDrop } from "../src/interfaces/ISeaDrop.sol";

import { PublicDrop } from "../src/lib/SeaDropStructs.sol";

contract DeploySassy is Script {
    // Addresses that stay common across chains
    address seadrop = 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5;
    address creator = 0x26faf8AE18d15Ed1CA0563727Ad6D4Aa02fb2F80;
    address feeRecipient = 0x0000a26b00c1F0DF003000390027140000fAa719;

    address LIMITBREAK_TRANSFER_VALIDATOR = 0xdA4289fBDb4eE0995ef7155F2AB29fc2CfC12B12;
    // Token config
    uint256 maxSupply = 5050;

    // Drop config
    uint16 feeBps = 300; // 3%
    uint80 mintPrice = 0.0001 ether;
    uint16 maxTotalMintableByWallet = 3;

    function run() external {
        vm.startBroadcast();

        address[] memory allowedSeadrop = new address[](1);
        allowedSeadrop[0] = seadrop;

        Sassy token = new Sassy(
            "Sassy Drop 6",
            "SD6",
            allowedSeadrop
        );

        // Configure the token.
        token.setMaxSupply(maxSupply);

        // Configure the drop parameters.
        token.updateCreatorPayoutAddress(seadrop, creator);
        token.updateAllowedFeeRecipient(seadrop, feeRecipient, true);
        token.setTransferValidator(LIMITBREAK_TRANSFER_VALIDATOR);
        token.updatePublicDrop(
            seadrop,
            PublicDrop(
                mintPrice,
                uint48(block.timestamp), // start time
                uint48(block.timestamp) + 1000, // end time
                maxTotalMintableByWallet,
                feeBps,
                true
            )
        );

        //We are ready, let's mint the first 3 tokens!
        ISeaDrop(seadrop).mintPublic{ value: mintPrice * 1 }(
            address(token),
            feeRecipient,
            address(0),
            1 // quantity
        );
        token.toggleRevealPhaseActive();
        token.revealNftNoSignature(1, 1);
        console.log("Token URI", token.tokenURI(1));
    }
}
