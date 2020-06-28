// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title HatRegistry
 * @author Hadrien Croubois (@amxx)
 * @dev ERC721 representation of hats for rDai v2
 */

library Hats
{
	// from @openzeppelin/contracts/utils/EnumerableMap.sol
	struct MapEntry {
		bytes32 _key;
		bytes32 _value;
	}

	struct Map {
		// Storage of map keys and values
		MapEntry[] _entries;

		// Position of the entry defined by a key in the `entries` array, plus 1
		// because index 0 means a key is not in the map.
		mapping (bytes32 => uint256) _indexes;
	}

	/**
	 * @dev Adds a key-value pair to a map, or updates the value for an existing
	 * key. O(1).
	 *
	 * Returns true if the key was added to the map, that is if it was not
	 * already present.
	 */
	function _set(Map storage map, bytes32 key, bytes32 value) private returns (bool) {
		// We read and store the key's index to prevent multiple reads from the same storage slot
		uint256 keyIndex = map._indexes[key];

		if (keyIndex == 0) { // Equivalent to !contains(map, key)
			map._entries.push(MapEntry({ _key: key, _value: value }));
			// The entry is stored at length-1, but we add 1 to all indexes
			// and use 0 as a sentinel value
			map._indexes[key] = map._entries.length;
			return true;
		} else {
			map._entries[keyIndex - 1]._value = value;
			return false;
		}
	}

	/**
	 * @dev Removes a key-value pair from a map. O(1).
	 *
	 * Returns true if the key was removed from the map, that is if it was present.
	 */
	function _remove(Map storage map, bytes32 key) private returns (bool) {
		// We read and store the key's index to prevent multiple reads from the same storage slot
		uint256 keyIndex = map._indexes[key];

		if (keyIndex != 0) { // Equivalent to contains(map, key)
			// To delete a key-value pair from the _entries array in O(1), we swap the entry to delete with the last one
			// in the array, and then remove the last entry (sometimes called as 'swap and pop').
			// This modifies the order of the array, as noted in {at}.

			uint256 toDeleteIndex = keyIndex - 1;
			uint256 lastIndex = map._entries.length - 1;

			// When the entry to delete is the last one, the swap operation is unnecessary. However, since this occurs
			// so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

			MapEntry storage lastEntry = map._entries[lastIndex];

			// Move the last entry to the index where the entry to delete is
			map._entries[toDeleteIndex] = lastEntry;
			// Update the index for the moved entry
			map._indexes[lastEntry._key] = toDeleteIndex + 1; // All indexes are 1-based

			// Delete the slot where the moved entry was stored
			map._entries.pop();

			// Delete the index for the deleted slot
			delete map._indexes[key];

			return true;
		} else {
			return false;
		}
	}

	/**
	 * @dev Returns true if the key is in the map. O(1).
	 */
	function _contains(Map storage map, bytes32 key) private view returns (bool) {
		return map._indexes[key] != 0;
	}

	/**
	 * @dev Returns the number of key-value pairs in the map. O(1).
	 */
	function _length(Map storage map) private view returns (uint256) {
		return map._entries.length;
	}

	/**
	 * @dev Returns the key-value pair stored at position `index` in the map. O(1).
	 *
	 * Note that there are no guarantees on the ordering of entries inside the
	 * array, and it may change when more entries are added or removed.
	 *
	 * Requirements:
	 *
	 * - `index` must be strictly less than {length}.
	 */
	function _at(Map storage map, uint256 index) private view returns (bytes32, bytes32) {
		require(map._entries.length > index, "EnumerableMap: index out of bounds");

		MapEntry storage entry = map._entries[index];
		return (entry._key, entry._value);
	}

	/**
	 * @dev Returns the value associated with `key`.  O(1).
	 *
	 * Requirements:
	 *
	 * - `key` must be in the map.
	 */
	function _get(Map storage map, bytes32 key) private view returns (bytes32) {
		return _get(map, key, "EnumerableMap: nonexistent key");
	}

	/**
	 * @dev Same as {_get}, with a custom error message when `key` is not in the map.
	 */
	function _get(Map storage map, bytes32 key, string memory errorMessage) private view returns (bytes32) {
		uint256 keyIndex = map._indexes[key];
		require(keyIndex != 0, errorMessage); // Equivalent to contains(map, key)
		return map._entries[keyIndex - 1]._value; // All indexes are 1-based
	}

	// Hat: address → uint256 with total

	struct Hat {
		address _strategy;
		Map     _portions;
		uint256 _total;
	}

	function set(Hat storage hat, address key, uint256 value) internal returns (bool) {
		hat._total -= get(hat, key);
		hat._total += value;
		return _set(hat._portions, bytes32(uint256(key)), bytes32(value));
	}

	function remove(Hat storage hat, address key) internal returns (bool) {
		hat._total -= get(hat, key);
		return _remove(hat._portions, bytes32(uint256(key)));
	}

	function contains(Hat storage hat, address key) internal view returns (bool) {
		return _contains(hat._portions, bytes32(uint256(key)));
	}

	function length(Hat storage hat) internal view returns (uint256) {
		return _length(hat._portions);
	}

	function at(Hat storage hat, uint256 index) internal view returns (address, uint256) {
		(bytes32 key, bytes32 value) = _at(hat._portions, index);
		return (address(uint256(key)), uint256(value));
	}

	function get(Hat storage hat, address key) internal view returns (uint256) {
		return uint256(_get(hat._portions, bytes32(uint256(key))));
	}

	function get(Hat storage hat, address key, string memory errorMessage) internal view returns (uint256) {
		return uint256(_get(hat._portions, bytes32(uint256(key)), errorMessage));
	}

	function weight(Hat storage hat) internal view returns (uint256)
	{
		return hat._total;
	}
}

contract HatRegistry is ERC721
{
	using Counters for Counters.Counter;
	using Hats     for Hats.Hat;

	Counters.Counter             private counter;
	mapping(uint256 => Hats.Hat) private hats;

	constructor()
	public ERC721("rDAI V2 Hats registry", "Hats")
	{}

	function createHat(
		address owner,
		address strategy,
		address[] calldata recipients,
		uint256[] calldata proportions)
	external
	{
		require(recipients.length == proportions.length);
		// increment counter
		counter.increment();
		// mint hat
		_mint(owner, counter.current());
		// configure hat
		Hats.Hat storage hat = hats[counter.current()];
		hat._strategy = strategy;
		for (uint256 i = 0; i < recipients.length; ++i)
		{
			hat.set(recipients[i], proportions[i]);
		}
	}

	// Warning: not accruing interest before updating will make the update retroactive
	function updateRecipient(
		uint256 hatId,
		address recipient,
		uint256 proportion)
	external
	{
		// only hat owner can update
		require(_msgSender() == ownerOf(hatId), "access-restricted-to-hat-owner");
		// null proportion → remove
		if (proportion == 0)
		{
			hats[hatId].remove(recipient);
		}
		// positive position → update
		else
		{
			hats[hatId].set(recipient, proportion);
		}
	}

	function viewHat(uint256 hatId)
	external view returns (
		address strategy,
		uint256 weight,
		address[] memory recipients,
		uint256[] memory proportions)
	{
		Hats.Hat storage hat = hats[hatId];
		uint256 length = hat.length();
		strategy       = hat._strategy;
		weight         = hat.weight();
		recipients     = new address[](length);
		proportions    = new uint256[](length);

		for (uint256 i = 0; i < length; ++i)
		{
			(address recipient, uint256 proportion) = hat.at(i);
			recipients[i]  = recipient;
			proportions[i] = proportion;
		}
	}
}
