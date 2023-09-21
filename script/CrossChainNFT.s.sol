// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "./Helper.sol";
import {CCIPavax} from "../src/CCIPavax.sol";
import {CCIPeth} from "../src/CCIPeth.sol";

contract DeployCCIPeth is Script, Helper {
    function run(SupportedNetworks destination) external {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(senderPrivateKey);

        (address router, , ) = getConfigFromNetwork(destination);
        address admin = 0xdb8354170b8E3f8B25948631D043df7AFe5bB58A;
        address cozyPenguinNft = 0x63d48Ed3f50aBA950c17e37CA03356CCd6b6a280;

        CCIPeth ccipEth = new CCIPeth(router, admin, cozyPenguinNft);

        console.log(
            "DeployCCIPeth deployed on ",
            networks[destination],
            "with address: ",
            address(ccipEth)
        );

        vm.stopBroadcast();
    }
}
