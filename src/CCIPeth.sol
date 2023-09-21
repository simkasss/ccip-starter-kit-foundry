// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Withdraw} from "./utils/Withdraw.sol";
import {ICozyPenguin} from "./utils/ICozyPenguin.sol";

contract CCIPeth is CCIPReceiver, Withdraw, IERC721Receiver {
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);
    error NothingToWithdraw();
    error NotConfirmedSourceChain(uint64 sourceChainSelector);
    error NotConfirmedSender(address sender);
    error NotOwner(address caller, uint256 tokenId);
    error NotAdmin(address caller);
    error TravelLocked();

    // Do we need more information in these events?
    event MessageSent(bytes32 messageId);
    event MessageReceived(bytes32 messageId);

    bytes32 private lastReceivedMessageId; // Store the last received messageId. Do we need this?

    ICozyPenguin cozyPenguin;
    address receiver;
    address admin;
    uint64 destinationChainSelector;
    uint64 sourceChainSelector;
    address confirmedSender;
    bool travelLock = false;

    constructor(
        address _router,
        address _admin,
        address _cozyPenguinNft
    ) CCIPReceiver(_router) {
        admin = _admin;
        cozyPenguin = ICozyPenguin(_cozyPenguinNft);
    }

    modifier onlyNftOwner(uint256[] calldata _tokenIds) {
        for (uint256 i = 0; i <= _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            if (cozyPenguin.ownerOf(tokenId) != msg.sender) {
                revert NotOwner(msg.sender, tokenId);
            }
        }
        _;
    }
    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert NotAdmin(msg.sender);
        }
        _;
    }

    modifier onlyConfirmedSender(address _sender) {
        if (_sender != confirmedSender) {
            revert NotConfirmedSender(_sender);
        }
        _;
    }
    modifier onlyConfirmedSourceChain(uint64 _sourceChainSelector) {
        if (_sourceChainSelector != sourceChainSelector) {
            revert NotConfirmedSourceChain(_sourceChainSelector);
        }
        _;
    }

    // This modifier is for security reasons, in case if we have to change how penguins travel
    modifier unlocked() {
        if (travelLock != false) {
            revert TravelLocked();
        }
        _;
    }

    /** Gets the required fee amount (by calling router contract).
     * If the user confirms required fee amount, the travel function is called.*/
    function travelRequest(
        uint256[] calldata _tokenIds
    ) external view onlyNftOwner(_tokenIds) unlocked returns (uint256 fees) {
        bytes memory messageData = abi.encode(msg.sender, _tokenIds); // ABI-encoded string message
        Client.EVM2AnyMessage memory message = _buildCCIPMessage(messageData);

        IRouterClient router = IRouterClient(this.getRouter());

        fees = router.getFee(destinationChainSelector, message);
        return fees;
    }

    function _buildCCIPMessage(
        bytes memory _messageData
    ) internal view returns (Client.EVM2AnyMessage memory) {
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: _messageData,
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array as no tokens are transferred
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and non-strict sequencing mode
                Client.EVMExtraArgsV1({gasLimit: 200_000, strict: false})
            ),
            feeToken: address(0)
        });
        return evm2AnyMessage;
    }

    /** Locks the existing NFTs on Ethereum.
     * Sends the message through the router and stores the returned CCIP message id. */
    function travel(
        uint256[] calldata _tokenIds,
        Client.EVM2AnyMessage memory _message,
        uint256 _fees
    )
        external
        payable
        onlyNftOwner(_tokenIds)
        unlocked
        returns (bytes32 messageId)
    {
        IRouterClient router = IRouterClient(this.getRouter());

        if (_fees > address(this).balance)
            revert NotEnoughBalance(address(this).balance, _fees);

        /** Locks the existing NFTs on Ethereum*/
        for (uint256 i = 0; i <= _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            cozyPenguin.safeTransferFrom(msg.sender, address(this), tokenId);
        }
        /** Sends message */
        messageId = router.ccipSend{value: _fees}(
            destinationChainSelector,
            _message
        );
        emit MessageSent(messageId);
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    )
        internal
        override
        onlyConfirmedSender(abi.decode(message.sender, (address)))
        onlyConfirmedSourceChain(message.sourceChainSelector)
    {
        lastReceivedMessageId = message.messageId;
        address owner;
        uint256[] memory tokenIds;
        (owner, tokenIds) = abi.decode(message.data, (address, uint256[]));

        unlockPenguin(owner, tokenIds);

        emit MessageReceived(message.messageId);
    }

    /** Unlocks the existing NFTs on Ethereum.
     * Only the contract itself can call it.
     */
    function unlockPenguin(
        address _owner,
        uint256[] memory _tokenIds
    ) internal {
        for (uint256 i = 0; i <= _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            cozyPenguin.safeTransferFrom(address(this), _owner, tokenId);
        }
    }

    /** Fallback function to allow the contract to receive Ether. */
    receive() external payable {}

    /** Admin functions: */

    function initalizeOrchangeReceiverAddress(
        address _receiver
    ) public onlyAdmin {
        receiver = _receiver;
    }

    function changeDestinationChainSelector(
        uint64 _destinationChainSelector
    ) public onlyAdmin {
        destinationChainSelector = _destinationChainSelector;
    }

    function changeSourceChainSelector(
        uint64 _sourceChainSelector
    ) public onlyAdmin {
        sourceChainSelector = _sourceChainSelector;
    }

    function changeSenderAddress(address _sender) public onlyAdmin {
        confirmedSender = _sender;
    }

    function changeAdmin(address _admin) public onlyAdmin {
        admin = _admin;
    }

    function lockTravel(bool _lock) public onlyAdmin {
        travelLock = _lock;
    }

    // from IERC721Receiver
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        // Add your custom logic here to handle the received token
        // For example, you can check the `from` address and tokenId to perform actions
        // For example, we're just returning the ERC721_RECEIVED selector
        return IERC721Receiver.onERC721Received.selector;
    }
}
