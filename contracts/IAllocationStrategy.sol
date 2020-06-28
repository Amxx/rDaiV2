// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

/**
 * @title IAllocationStrategy
 * @author Hadrien Croubois (@amxx)
 * @dev Allocation strategy interface for rDaiV2
 */

interface IAllocationStrategy
{
	function deposit (uint256, address) external returns (uint256);
	function withdraw(uint256, address) external returns (uint256);
	function refToUnderlying(uint256)   external returns (uint256);
}
