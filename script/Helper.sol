// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Helper {
    // Supported Networks
    enum SupportedNetworks {
        ETHEREUM_SEPOLIA,
        AVALANCHE_FUJI
    }

    mapping(SupportedNetworks enumValue => string humanReadableName)
        public networks;

    // Chain IDs
    uint64 constant chainIdEthereumSepolia = 16015286601757825753;
    uint64 constant chainIdAvalancheFuji = 14767482510784806043;

    // Router addresses
    address constant routerEthereumSepolia =
        0xD0daae2231E9CB96b94C8512223533293C3693Bf;
    address constant routerAvalancheFuji =
        0x554472a2720E5E7D5D3C817529aBA05EEd5F82D8;

    // Wrapped native addresses
    address constant wethEthereumSepolia =
        0x097D90c9d3E0B50Ca60e1ae45F6A81010f9FB534;
    address constant wavaxAvalancheFuji =
        0xd00ae08403B9bbb9124bB305C09058E32C39A48c;

    constructor() {
        networks[SupportedNetworks.ETHEREUM_SEPOLIA] = "Ethereum Sepolia";
        networks[SupportedNetworks.AVALANCHE_FUJI] = "Avalanche Fuji";
    }

    function getConfigFromNetwork(
        SupportedNetworks network
    )
        internal
        pure
        returns (address router, address wrappedNative, uint64 chainId)
    {
        if (network == SupportedNetworks.ETHEREUM_SEPOLIA) {
            return (
                routerEthereumSepolia,
                wethEthereumSepolia,
                chainIdEthereumSepolia
            );
        } else if (network == SupportedNetworks.AVALANCHE_FUJI) {
            return (
                routerAvalancheFuji,
                wavaxAvalancheFuji,
                chainIdAvalancheFuji
            );
        }
    }
}
