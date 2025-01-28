// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BasicBlueprint, TokenOp, IBlueprintManager} from "../BasicBlueprint.sol";
import {gcd} from "../../libraries/Math.sol";

// an overly simplified option blueprint which leaks value to arbitrageurs at expiry
contract MicroOptionBlueprint is BasicBlueprint {
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
            bool mint
        ) = abi.decode(
                action,
                (uint256, uint256, uint256, uint256, uint256, bool)
            );

        TokenOp[] memory giveTake = oneOperationArray(token0, num);

        uint256 amount = gcd(num, denom);
        require(amount > 0, "Amount cannot be zero");

        (num, denom) = (num / amount, denom / amount);

        bool swap;
        assembly {
            // Compare token1 and token0
            swap := lt(token1, token0)

            // If swap is true, swap token0 and token1, and swap num and denom
            if swap {
                // Swap token0 and token1
                let temp := token0
                token0 := token1
                token1 := temp

                // Swap num and denom
                let temp2 := num
                num := denom
                denom := temp2
            }
        }

        uint256 short;
        uint256 long;

        assembly {
            // Allocate memory for the packed data
            let ptr := mload(0x40) // Load free memory pointer

            // Pack the data: token0, token1, num, denom, expiry
            mstore(ptr, token0)
            mstore(add(ptr, 0x20), token1)
            mstore(add(ptr, 0x40), num)
            mstore(add(ptr, 0x60), denom)
            mstore(add(ptr, 0x80), expiry)

            // Compute keccak256 hash of the packed data
            let hash := keccak256(ptr, 0xA0) // 0xA0 = 5 * 0x20 (5 elements, each 32 bytes)

            // Compute short = hash + 2
            short := add(hash, 2)

            // Compute long = short - (swap ? 1 : 2)
            switch swap
            case 1 {
                long := sub(short, 1)
            }
            default {
                long := sub(short, 2)
            }
        }

        TokenOp[] memory mintBurn = new TokenOp[](2);
        mintBurn[0] = TokenOp(short, amount);
        if (block.timestamp < expiry || mint)
            mintBurn[1] = TokenOp(long, amount);

        if (mint)
            reserves[long] += amount; // underflow check prevents from going beyond reserves
        else reserves[long] -= amount;

        return
            mint
                ? (mintBurn, zero(), zero(), giveTake)
                : (zero(), mintBurn, giveTake, zero());
    }
}
