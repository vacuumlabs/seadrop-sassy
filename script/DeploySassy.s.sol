// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {Sassy} from "../src/SassySeadrop.sol";

import {ISeaDrop} from "../src/interfaces/ISeaDrop.sol";
import {ISeaDropTokenContractMetadata} from "../src/interfaces/ISeaDropTokenContractMetadata.sol";

import {PublicDrop} from "../src/lib/SeaDropStructs.sol";

contract DeploySassy is Script {
    // Addresses that stay common across chains
    address seadrop = 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5;
    address creator = 0x26faf8AE18d15Ed1CA0563727Ad6D4Aa02fb2F80;
    address feeRecipient = 0x0000a26b00c1F0DF003000390027140000fAa719;

    address USDC_CONTRACT_ADDRESS = vm.envAddress("USDC_ADDRESS");

    // Token config
    uint256 maxSupply = 5050;

    // Drop config
    uint16 feeBps = 300; // 3% Secondary Sale Fee
    uint80 mintPrice = 0.0001 ether;
    uint16 maxTotalMintableByWallet = 3;

    function run() external {
        vm.startBroadcast();

        address[] memory allowedSeadrop = new address[](1);
        allowedSeadrop[0] = seadrop;

        Sassy token = new Sassy("Sassy Shredders", "Sassy Shredders", allowedSeadrop, USDC_CONTRACT_ADDRESS);

        // Configure the token.
        token.setMaxSupply(maxSupply);

        // Configure the drop parameters.
        token.updateCreatorPayoutAddress(seadrop, creator);
        token.updateAllowedFeeRecipient(seadrop, feeRecipient, true);
        token.updatePublicDrop(
            seadrop,
            PublicDrop(
                mintPrice,
                uint48(block.timestamp), // start time (TODO: Set it to Date of mint)
                uint48(block.timestamp) + 259200, // end time (3 days)
                maxTotalMintableByWallet,
                feeBps,
                true
            )
        );
    }
}
