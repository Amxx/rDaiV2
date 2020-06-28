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
	address public override underlyingAsset;

	constructor(address _underlyingAsset)
	public
	{
		underlyingAsset = _underlyingAsset;
	}

	/**
	 * @dev Deposit underlying tokens to investment mechanism. Module must be approved by `_from`
	 *
	 * Returns Number of investement tokens minted in the proccess.
	 */
	function deposit(uint256 _amount, address _from)
	external override onlyOwner() returns (uint256)
	{
		IERC20(underlyingAsset).transferFrom(_from, address(this), _amount);
		return _amount;
	}

	/**
	 * @dev Withdraw underlying tokens from the investment mechanism. Any additional assets (such as Comp token) should be sent to `_toExtra`
	 *
	 * Returns Number of investement tokens burned in the proccess.
	 */
	function withdraw(uint256 _amount, address _to, address /* _toExtra */)
	external override onlyOwner() returns (uint256)
	{
		IERC20(underlyingAsset).transfer(_to, _amount);
		return _amount;
	}

	/**
	 * @dev investment token to underlying token convertion.
	 *
	 * Returns Quantity of underlyingAsset corresponding to `_ref` investment tokens.
	 */
	function refToUnderlying(uint256 _ref)
	external override returns (uint256)
	{
		return _ref;
	}
}
