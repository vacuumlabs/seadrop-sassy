// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {Sassy} from "../src/SassySeadrop.sol";

import {ISeaDrop} from "../src/interfaces/ISeaDrop.sol";
import {ISeaDropTokenContractMetadata} from "../src/interfaces/ISeaDropTokenContractMetadata.sol";

import {PublicDrop} from "../src/lib/SeaDropStructs.sol";

contract DeploySassy is Script {
    // Common across chains
    address seadrop = 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5;

    // Deployer Private Key
    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.addr(privateKey);
    
    // Address to get creator payouts
    address creator = vm.envAddress("CREATOR_PAYOUT_ADDRESS");
    // Address to receive marketplace fee
    address feeRecipient = vm.envAddress("FEE_RECIPIENT_ADDRESS");

    address USDC_CONTRACT_ADDRESS = vm.envAddress("USDC_ADDRESS");

    // Token config
    uint256 maxSupply = 5050;

    // Drop config
    uint16 feeBps = 300; // 3% Secondary Sale Fee
    uint80 mintPrice = 0.0001 ether;
    uint16 maxTotalMintableByWallet = 3;

    function run() external {
        vm.startBroadcast(privateKey);

        address[] memory allowedSeadrop = new address[](1);
        allowedSeadrop[0] = seadrop;

        Sassy token = new Sassy("Sassy Shredders", "SASS", allowedSeadrop, USDC_CONTRACT_ADDRESS);

        // Configure the token.
        token.setMaxSupply(maxSupply);

        // Configure the drop parameters.
        token.updateCreatorPayoutAddress(seadrop, creator);
        token.updateAllowedFeeRecipient(seadrop, feeRecipient, true);
        token.setUnrevealedNftUri("https://jade-perfect-gibbon-918.mypinata.cloud/ipfs/bafkreieltelsnuyjlsirn4aexa4yqudfgtpagrbsjbymqtwzjnpx4jo34i");
        token.setRarityAssignerAddress(0x129b916d1F226f8aC03978834688A836C250C736);
    }
}
