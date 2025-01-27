// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BasicBlueprint, TokenOp, IBlueprintManager} from "../BasicBlueprint.sol";
import {gcd} from "../../libraries/Math.sol";

contract SimpleOptionBlueprint is BasicBlueprint {
    mapping(uint256 => uint256) public reserves;

    constructor(IBlueprintManager manager) BasicBlueprint(manager) {}

    function executeAction(bytes calldata action)
        external
        onlyManager
        returns (
            TokenOp[] memory, /*mint*/
            TokenOp[] memory, /*burn*/
            TokenOp[] memory, /*give*/
            TokenOp[] memory /*take*/
        )
    {
        (
            uint256 token0,
            uint256 token1,
            uint256 num,
            uint256 denom,
            uint256 expiry,
            uint256 settlement,
            address settler,
            bool mint
        ) = abi.decode(
                action,
                (
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    uint256,
                    address,
                    bool
                )
            );

        TokenOp[] memory giveTake = oneOperationArray(token0, num);

        (uint256 short, uint256 long, uint256 amount) = getTokens(
            token0,
            token1,
            num,
            denom,
            expiry,
            settlement,
            settler
        );

        TokenOp[] memory mintBurn = new TokenOp[](2);
        mintBurn[0] = TokenOp(short, amount);
        mintBurn[1] = TokenOp(long, amount);

        if (mint)
            reserves[long] += amount; // underflow check prevents from going beyond reserves
        else reserves[long] -= amount;

        return
            mint
                ? (mintBurn, zero(), zero(), giveTake)
                : (zero(), mintBurn, giveTake, zero());
    }

    function mint(
        address to,
        uint256 token0,
        uint256 token1,
        uint256 num,
        uint256 denom,
        uint256 expiry,
        uint256 settlement,
        address settler
    ) external {
        assembly {
            // Check if block.timestamp <= expiry
            let condition1 := lt(timestamp(), add(expiry, 1)) // timestamp() <= expiry

            // Check if block.timestamp <= settlement && msg.sender != settler
            let condition2 := and(
                lt(timestamp(), add(settlement, 1)), // timestamp() <= settlement
                iszero(eq(caller(), settler)) // msg.sender != settler
            )

            // Combine conditions: condition1 || condition2
            let accessDenied := or(condition1, condition2)

            // Revert if accessDenied is true
            switch accessDenied
            case 1 {
                // Revert with AccessDenied()
                let ptr := mload(0x40) // Load free memory pointer
                mstore(
                    ptr,
                    0x4e487b7100000000000000000000000000000000000000000000000000000000
                ) // Error selector for AccessDenied()
                mstore(add(ptr, 0x04), 0x20) // Offset for the error message
                mstore(add(ptr, 0x24), 0x0c) // Length of the error message
                mstore(add(ptr, 0x44), "AccessDenied") // Error message
                revert(ptr, 0x64) // Revert with the error
            }
        }
        (, uint256 long, uint256 amount) = getTokens(
            token0,
            token1,
            num,
            denom,
            expiry,
            settlement,
            settler
        );

        blueprintManager.mint(to, long, amount);
    }

    function getTokens(
        uint256 token0,
        uint256 token1,
        uint256 num,
        uint256 denom,
        uint256 expiry,
        uint256 settlement,
        address settler
    )
        internal
        pure
        returns (
            uint256 short,
            uint256 long,
            uint256 amount
        )
    {
        amount = gcd(num, denom);
        (num, denom) = (num / amount, denom / amount);

        bool swap;
        assembly {
            // Compare token1 and token0
            swap := lt(token1, token0)

            // If swap is true, swap token0 and token1, and swap num and denom
            if swap {
                // Swap token0 and token1
                let ptr := token0
                token0 := token1
                token1 := ptr

                // Swap num and denom
                let ptr2 := num
                num := denom
                denom := ptr2
            }
        }

        uint256 id = uint256(
            keccak256(
                abi.encodePacked(
                    token0,
                    token1,
                    num,
                    denom,
                    expiry,
                    settlement,
                    settler
                )
            )
        );

        assembly {
            // Compute short = id + 2
            short := add(id, 2)

            // Compute long = id + (swap ? 1 : 0)
            switch swap
            case 1 {
                long := add(id, 1)
            }
            default {
                long := add(id, 0)
            }
        }
    }
}
