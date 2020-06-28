// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IAllocationStrategy.sol";

/**
 * @title rDaiV2Module_Mock
 * @author Hadrien Croubois (@amxx)
 * @dev Mock module for rDaiV2, no investment
 */


contract rDaiV2Module_Mock is IAllocationStrategy, Ownable
{
	IERC20 public underlyingAsset;

	constructor(address _underlyingAsset)
	public
	{
		underlyingAsset = IERC20(_underlyingAsset);
	}

	function deposit(uint256 _amount, address _from)
	external override onlyOwner() returns (uint256)
	{
		underlyingAsset.transferFrom(_from, address(this), _amount);
		return _amount;
	}

	function withdraw(uint256 _amount, address _to)
	external override onlyOwner() returns (uint256)
	{
		underlyingAsset.transfer(_to, _amount);
		return _amount;
	}

	function refToUnderlying(uint256 _ref)
	external override returns (uint256)
	{
		return _ref;
	}
}
