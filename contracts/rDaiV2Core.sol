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

	/**
	 * @dev Mint rDai tokens for the `_id` hat.
	 *
	 * Requirements: _msgSender must approve `_amount` underlying tokens to the hat's module
	 */
	function mint(uint256 _id, uint256 _amount)
	public
	{
		address sender = _msgSender();
		refSupply[_id] += IAllocationStrategy(hatRegistry.viewStrategy(_id)).deposit(_amount, sender); // should not need safemath
		_mint(sender, _id, _amount, "");
	}

	/**
	 * @dev Redeem rDai tokens for the `_id` hat.
	 */
	function redeem(uint256 _id, uint256 _amount)
	public
	{
		address sender = _msgSender();
		_burn(sender, _id, _amount);
		refSupply[_id] -= IAllocationStrategy(hatRegistry.viewStrategy(_id)).withdraw(_amount, sender, sender); // should not need safemath
	}

	/**
	 * @dev Reallocate rDai tokens between 2 hats that share the same underlying asset. Any extra token produced by the initial hat will be sent to the _msgSender()
	 */
	function reallocate(uint256 _idFrom, uint256 _idTo, uint256 _amount)
	public
	{
		address sender = _msgSender();

		IAllocationStrategy from = IAllocationStrategy(hatRegistry.viewStrategy(_idFrom));
		IAllocationStrategy to = IAllocationStrategy(hatRegistry.viewStrategy(_idTo));

		require(from.underlyingAsset() == to.underlyingAsset());

		_burn(sender, _idFrom, _amount);
		refSupply[_idFrom] -= from.withdraw(_amount, address(this), sender); // should not need safemath
		IERC20(to.underlyingAsset()).approve(address(to), _amount);
		refSupply[_idTo] += to.deposit(_amount, address(this)); // should not need safemath
		_mint(sender, _idTo, _amount, "");
	}

	/**
	 * @dev Register interests for a hat by minting the corresponding amount of rDai on the recipients buckets.
	 */
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
		uint256 distribute = balance - totalSupply[_id];
		// distribute new stuff
		for (uint256 i = 1; i < recipients.length; ++i)
		{
			_mint(recipients[i], _id, distribute * proportions[i] / weight, "");
		}
		// sanity, everything not yet distributed to recipient[0]
		_mint(recipients[0], _id, balance - totalSupply[_id], "");
	}

	/**
	 * @dev Overload _mint to support totalSupply per hat.
	 */
	function _mint(address account, uint256 id, uint256 amount, bytes memory data)
	internal virtual override
	{
		ERC1155._mint(account, id, amount, data);
		totalSupply[id] += amount; // should not need safemath
	}

	/**
	 * @dev Overload _burn to support totalSupply per hat.
	 */
	function _burn(address account, uint256 id, uint256 amount)
	internal virtual override
	{
		ERC1155._burn(account, id, amount);
		totalSupply[id] -= amount; // should not need safemath
	}
}
