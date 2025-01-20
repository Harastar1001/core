// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BasicBlueprint, TokenOp, IBlueprintManager} from "../BasicBlueprint.sol";
import {SafeTransferLib, ERC20} from "solmate/utils/SafeTransferLib.sol";
import {IAllowanceTransfer} from "../../../permit2/src/interfaces/IAllowanceTransfer.sol";
import {Permit2} from "../../../permit2/src/Permit2.sol";

contract ERC20Blueprint is BasicBlueprint {
    error ReentrantDeposit();
    error BalanceOverflow();
    error InvalidPermitSignature();

    address internal constant registry = 0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24;
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3; // Mainnet Permit2 address

    IAllowanceTransfer public permit2;

    constructor(IBlueprintManager manager) BasicBlueprint(manager) {
        permit2 = IAllowanceTransfer(PERMIT2);
    }

    // ==================== Permit2 Integration ====================

    /**
     * @notice Deposit tokens using a Permit2 signature.
     * @param erc20 The address of the ERC20 token.
     * @param to The address to mint tokens to.
     * @param amount The amount of tokens to deposit.
     * @param permit The Permit2 permit data.
     * @param signature The user's signature for the permit.
     * @return deposited The amount of tokens deposited.
     */
    function depositWithPermit2(
        address erc20,
        address to,
        uint256 amount,
        IAllowanceTransfer.PermitSingle calldata permit,
        bytes calldata signature
    ) external returns (uint256 deposited) {
        // Verify the permit signature
        permit2.permit(msg.sender, permit, signature);

        // Transfer tokens from the user to this contract using Permit2
        permit2.transferFrom(msg.sender, address(this), amount, erc20);

        // Mint tokens to the recipient
        return _mintNewBalance(erc20, to);
    }

    // ==================== Existing Functions ====================

    function executeAction(bytes calldata action) external onlyManager returns (
        TokenOp[] memory /*mint*/,
        TokenOp[] memory /*burn*/,
        TokenOp[] memory /*give*/,
        TokenOp[] memory /*take*/
    ) {
        (address erc20, address to, uint256 amount) =
            abi.decode(action, (address, address, uint256));

        SafeTransferLib.safeTransfer(ERC20(erc20), to, amount);

        return (
            zero(),
            oneOperationArray(uint256(uint160(erc20)), amount),
            zero(),
            zero()
        );
    }

    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata data,
        bytes calldata /*operatorData*/
    ) external {
        if (operator != address(this) && to == address(this)) {
            uint256 savedBalance = _getSavedBalance(msg.sender);
            if (savedBalance != type(uint256).max)
                _saveBalance(msg.sender, savedBalance + amount);

            if (data.length == 32)
                (from) = abi.decode(data, (address));

            blueprintManager.mint(from, uint256(uint160(msg.sender)), amount);
        }
    }

    function deposit(address erc20, address to, uint256 amount) external returns (uint256 deposited) {
        return _deposit(erc20, msg.sender, to, amount);
    }

    function permitDeposit(
        address erc20,
        address to,
        uint256 amount,
        address owner,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 deposited) {
        if (owner != to && owner != msg.sender)
            revert AccessDenied();

        ERC20(erc20).permit(owner, address(this), amount, deadline, v, r, s);

        return _deposit(erc20, owner, to, amount);
    }

    function depositWithCallback(
        address erc20,
        address callback,
        bytes calldata callbackData
    ) external returns (uint256 deposited) {
        _saveBalance(erc20, _getBalance(erc20));

        IDepositor(callback).depositCallback(erc20, callbackData);

        return _mintNewBalance(erc20, msg.sender);
    }

    // ==================== Internal Functions ====================

    function _deposit(
        address erc20,
        address from,
        address to,
        uint256 amount
    ) internal returns (uint256 deposited) {
        _saveBalance(erc20, _getBalance(erc20));

        SafeTransferLib.safeTransferFrom(ERC20(erc20), from, address(this), amount);

        return _mintNewBalance(erc20, to);
    }

    function _getBalance(address erc20) internal view returns (uint256) {
        return ERC20(erc20).balanceOf(address(this));
    }

    function _saveBalance(address erc20, uint256 _balance) internal {
        if (_balance == type(uint256).max)
            revert BalanceOverflow();

        assembly {
            erc20 := shr(96, shl(96, erc20))
            tstore(erc20, add(_balance, 1))
        }
    }

    function _getSavedBalance(address erc20) internal view returns (uint256 _balance) {
        assembly {
            erc20 := shr(96, shl(96, erc20))
            _balance := sub(tload(erc20), 1)
        }
    }

    function _mintNewBalance(address erc20, address to) internal returns (uint256 delta) {
        uint256 newBalance = _getBalance(erc20);
        uint256 oldBalance = _getSavedBalance(erc20);
        delta = newBalance - oldBalance;

        blueprintManager.mint(to, uint256(uint160(erc20)), delta);
        _saveBalance(erc20, newBalance);
    }

    function setERC1820Registry() external {
        IERC1820Registry(registry).setInterfaceImplementer(
            address(this),
            keccak256("ERC777TokensRecipient"),
            address(this)
        );
    }
}