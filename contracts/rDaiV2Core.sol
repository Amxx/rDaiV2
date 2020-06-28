// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./HatRegistry.sol";
import "./IAllocationStrategy.sol";

/**
 * @title rDaiV2Core
 * @author Hadrien Croubois (@amxx)
 * @dev Core contract for rDaiV2
 */

contract rDaiV2Core is ERC1155
{
	HatRegistry public hatRegistry;
	mapping(uint256 => uint256) public totalSupply;
	mapping(uint256 => uint256) public refSupply;

	constructor(address _hatRegistry)
	public ERC1155("")
	{
		hatRegistry = HatRegistry(_hatRegistry);
	}

	function mint(uint256 _id, uint256 _amount)
	public
	{
		address sender = _msgSender();
		(address strategy,,,) = hatRegistry.viewHat(_id);
		refSupply[_id] += IAllocationStrategy(strategy).deposit(_amount, sender); // should not need safemath
		_mint(sender, _id, _amount, "");
	}

	function redeem(uint256 _id, uint256 _amount)
	public
	{
		address sender = _msgSender();
		(address strategy,,,) = hatRegistry.viewHat(_id);
		refSupply[_id] -= IAllocationStrategy(strategy).withdraw(_amount, sender, sender); // should not need safemath
		_burn(sender, _id, _amount);
	}

	function reallocate(uint256 _idFrom, uint256 _idTo, uint256 _amount)
	public
	{
		address sender = _msgSender();

		(address strategyFrom,,,) = hatRegistry.viewHat(_idFrom);
		(address strategyTo,,,) = hatRegistry.viewHat(_idTo);

		IAllocationStrategy from = IAllocationStrategy(strategyFrom);
		IAllocationStrategy to = IAllocationStrategy(strategyTo);

		require(from.underlyingAsset() == to.underlyingAsset());
		IERC20(to.underlyingAsset()).approve(address(to), _amount);
		refSupply[_idFrom] -= from.withdraw(_amount, address(this), sender); // should not need safemath
		refSupply[_idTo] += to.deposit(_amount, address(this)); // should not need safemath

		_burn(sender, _idFrom, _amount);
		_mint(sender, _idTo, _amount, "");
	}

	function accrue(uint256 _id)
	public
	{
		// get hat
		(
			address strategy,
			uint256 weight,
			address[] memory recipients,
			uint256[] memory proportions
		) = hatRegistry.viewHat(_id);
		// read underlying hat balance
		uint256 balance = IAllocationStrategy(strategy).refToUnderlying(refSupply[_id]);
		uint256 distribute = totalSupply[_id] - balance;
		// distribute new stuff
		for (uint256 i = 1; i < recipients.length; ++i)
		{
			_mint(recipients[i], _id, distribute * proportions[i] / weight, "");
		}
		// sanity, everything not yet distributed to recipient[0]
		_mint(recipients[0], _id, totalSupply[_id] - balance, "");
	}

	function _mint(address account, uint256 id, uint256 amount, bytes memory data)
	internal virtual override
	{
		ERC1155._mint(account, id, amount, data);
		totalSupply[id] += amount; // should not need safemath
	}

	function _burn(address account, uint256 id, uint256 amount)
	internal virtual override
	{
		ERC1155._burn(account, id, amount);
		totalSupply[id] -= amount; // should not need safemath
	}
}
