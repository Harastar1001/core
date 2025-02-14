// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IVestingSchedule {
	function getVestedTokens(
		uint256 amount,
		bytes calldata scheduleArgs
	) external view returns (uint256 unlocked);
}
