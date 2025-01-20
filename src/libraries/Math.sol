// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// gcd(0, 0) = 0
 function gcd(uint256 a, uint256 b)  pure returns (uint256) {
        assembly {
            // Main loop continues while b != 0
            for {} iszero(iszero(b)) {} {
                // Store original value of a
                let temp := a
                
                // a = b
                a := b
                
                // b = temp % b (original a % b)
                b := mod(temp, b)
            }
            
            // Return final value of a
            mstore(0x0, a)
            return(0x0, 0x20)
        }
    }
