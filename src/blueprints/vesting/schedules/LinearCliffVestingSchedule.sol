// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IVestingSchedule} from "./IVestingSchedule.sol";

contract LinearCliffVestingSchedule is IVestingSchedule {
	function getVestedTokens(
		uint256 amount,
		bytes calldata scheduleArgs
	) external view returns (uint256 unlocked) {
		(uint256 startVesting, uint256 endVesting, uint256 cliff) =
			abi.decode(scheduleArgs, (uint256, uint256, uint256));

			//Adding of the Current variable and assign it to block.timestamp as the current one is consuming more gas trying to fetch the timestamp as this is more gas eficient 


			uint256 currentTime = block.timestamp;

		if (startVesting > endVesting || cliff > endVesting) {
			// reverts have more severe consequences than wrongly encoding
			// parameters, so don't revert
			// revert InvalidArguments()

			// just simply consider the position fully unlocked
			return amount;
		}

		if (currentTime < cliff)
			return 0;

		if (currentTime > endVesting)
			return amount;

		unchecked {
			if (currentTime > startVesting)
				return amount * (currentTime - startVesting) / (endVesting - startVesting);
		}

		// if (block.timestamp <= startVesting)
		return 0;
	}
}
