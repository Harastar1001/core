// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IVestingSchedule} from "./IVestingSchedule.sol";

contract LinearCliffVestingSchedule is IVestingSchedule {
    function getVestedTokens(uint256 amount, bytes calldata scheduleArgs) external view returns (uint256 unlocked) {
        (uint256 startVesting, uint256 endVesting, uint256 cliff) =
            abi.decode(scheduleArgs, (uint256, uint256, uint256));

        uint256 currentTime = block.timestamp;

        assembly {

			//Getting the free memory pointer
			let freeMemPtr := mload(0x40)

            if or(gt(startVesting, endVesting), gt(cliff, endVesting)) {
                //if true return amount
                mstore(freeMemPtr, amount)
				//updating free memory pointer 
				mstore(0x40,add(freeMemPtr,0x20))
                return(freeMemPtr, 0x20)
            }

            if lt(currentTime, cliff) {
                mstore(freeMemPtr, 0)
				mstore(0x40, add(freeMemPtr,0x20))
                return(freeMemPtr, 0x20)
            }

            if gt(currentTime, endVesting) {
                mstore(freeMemPtr, amount)
				mstore(0x40,add(freeMemPtr,0x20))
                return(freeMemPtr, 0x20)
            }

            if gt(currentTime, startVesting) {
                let timeElapsed := sub(currentTime, startVesting)
                let vestingDuration := sub(endVesting, startVesting)
                let result1 := mul(amount, timeElapsed)
                let finResult := div(result1, vestingDuration)
                mstore(freeMemPtr, finResult)
				mstore(freeMemPtr,add(freeMemPtr,0x20))
                return(freeMemPtr, 0x20)
            }
			//Default case
            mstore(freeMemPtr, 0)
			mstore(0x40, add(freeMemPtr,0x20))
            return(freeMemPtr, 0x20)
        }
    }
}
