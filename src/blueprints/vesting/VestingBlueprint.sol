// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BasicBlueprint, TokenOp, IBlueprintManager} from "../BasicBlueprint.sol";
import {gcd} from "../../libraries/Math.sol";
import {IVestingSchedule} from "./schedules/IVestingSchedule.sol";

contract VestingBlueprint is BasicBlueprint {
	error UnalignedBatchSize();

	struct ActionParams {
		uint256 tokenId;
		uint256 amount;
		uint256 filled;
		address vestingSchedule;
		bytes scheduleArgs;
		uint256 preferredFinalBatch;
		uint256 desiredFillPerBatch;
	}

	constructor(IBlueprintManager _blueprintManager)
		BasicBlueprint(_blueprintManager) {}

	// the onlyManager modifier is removed because it's a pure/view function
function executeAction(
    bytes calldata action
) external view returns (
    TokenOp[] memory /*mint*/,
    TokenOp[] memory /*burn*/,
    TokenOp[] memory /*give*/,
    TokenOp[] memory /*take*/
) {
    ActionParams memory params;
    (
        params.tokenId,
        params.amount,
        params.filled,
        params.vestingSchedule,
        params.scheduleArgs,
        params.preferredFinalBatch,
        params.desiredFillPerBatch
    ) = abi.decode(action, (uint256, uint256, uint256, address, bytes, uint256, uint256));

    if (params.amount == 0)
        return (zero(), zero(), zero(), zero());

<<<<<<< Updated upstream
    if (params.amount % params.preferredFinalBatch != 0)
        revert UnalignedBatchSize();

    uint256 finalFilled = params.amount / params.preferredFinalBatch * params.desiredFillPerBatch;
    bool addTokens = finalFilled >= params.filled;
=======
		assembly {
			//load amount and finalbatch into memory 
			let _amount := amount
			let _preffBatch := preferredFinalBatch
			let remainder := mod(_amount,_preffBatch)

			//if remainder is not zero reert with custom errors

			if remainder {
				mstore(0x00,0x4e487b71)
				revert(0x00,0x04)
			}

		}
		bool addTokens;
		uint256 finalFilled;

		assembly {
			let amt := amount
			let prefBatch :=  preferredFinalBatch
			let desFill := desiredFillPerBatch
			let fin1 := div(amt,prefBatch)
			let finFilled := finalFilled
			finFilled := mul(fin1,desFill)
			let addTkn := addTokens
			let filled11 := filled
			addTkn := gt(finFilled,filled11)
		}
>>>>>>> Stashed changes

    uint256 initBatchDenom = gcd(params.amount, params.filled);
    bytes memory vestingStruct = getVestingStruct(
        params.tokenId,
        params.vestingSchedule,
        params.scheduleArgs
    );

    TokenOp[] memory burn = getOperation(
        vestingStruct,
        params.amount / initBatchDenom,
        params.filled / initBatchDenom,
        initBatchDenom
    );

    if (!addTokens) {
        uint256 maxFinalBatch = params.preferredFinalBatch -
            IVestingSchedule(params.vestingSchedule).getVestedTokens(
                params.preferredFinalBatch,
                params.scheduleArgs
            );
        if (maxFinalBatch > params.desiredFillPerBatch) {
            params.desiredFillPerBatch = maxFinalBatch;
            finalFilled = params.amount / params.preferredFinalBatch * params.desiredFillPerBatch;
            if (finalFilled >= params.filled)
                return (zero(), zero(), zero(), zero());
        }
    }

    uint256 finalBatchDenom = gcd(params.desiredFillPerBatch, params.preferredFinalBatch);
    uint256 finalBatchSize = params.preferredFinalBatch / finalBatchDenom;
    TokenOp[] memory mint = getOperation(
        vestingStruct,
        finalBatchSize,
        params.desiredFillPerBatch / finalBatchDenom,
        params.amount / finalBatchSize
    );

    (TokenOp[] memory give, TokenOp[] memory take) = addTokens ?
        (zero(), oneOperationArray(params.tokenId, finalFilled - params.filled)) :
        (oneOperationArray(params.tokenId, params.filled - finalFilled), zero());

    return (mint, burn, give, take);
}

	function getVestingStruct(
		uint256 tokenId,
		address vestingSchedule,
		bytes memory scheduleArgs
	) internal pure returns (bytes memory res) {
		assembly ("memory-safe") {
			res := mload(0x40)
			mstore(add(res, 0x20), tokenId)
			mstore(add(res, 0x74), vestingSchedule)

			let size := mload(scheduleArgs)
			mcopy(add(res, 0x94), add(scheduleArgs, 0x20), size)
			mstore(res, add(size, 0x74))
			mstore(0x40, add(res, add(size, 0x94)))
		}
	}

	function setVestingParams(
		bytes memory vestingStruct,
		uint256 amount,
		uint256 filled
	) internal pure {
		assembly ("memory-safe") {
			mstore(add(vestingStruct, 0x40), amount)
			mstore(add(vestingStruct, 0x60), filled)
		}
	}

	function getOperation(
		bytes memory vestingStruct,
		uint256 batchSize,
		uint256 fillPerBatch,
		uint256 amount
	) internal pure returns (TokenOp[] memory) {
		if (fillPerBatch != 0) {
			setVestingParams(
				vestingStruct,
				batchSize,
				fillPerBatch
			);
			return oneOperationArray(
				uint256(keccak256(vestingStruct)),
				amount
			);
		} else {
			return zero();
		}
	}
}
