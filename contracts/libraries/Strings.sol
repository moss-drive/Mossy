// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "./BytesLib.sol";
import "./console.sol";

/**
 * @dev String operations.
 */
library Strings {
	bytes16 private constant _SYMBOLS = "0123456789abcdef";
	uint8 private constant _ADDRESS_LENGTH = 20;

	/**
	 * @dev Converts a `uint256` to its ASCII `string` decimal representation.
	 */
	function toString(uint256 value) internal pure returns (string memory) {
		unchecked {
			uint256 length = Math.log10(value) + 1;
			string memory buffer = new string(length);
			uint256 ptr;
			/// @solidity memory-safe-assembly
			assembly {
				ptr := add(buffer, add(32, length))
			}
			while (true) {
				ptr--;
				/// @solidity memory-safe-assembly
				assembly {
					mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
				}
				value /= 10;
				if (value == 0) break;
			}
			return buffer;
		}
	}

	/**
	 * @dev Converts a `int256` to its ASCII `string` decimal representation.
	 */
	function toString(int256 value) internal pure returns (string memory) {
		return string.concat(value < 0 ? "-" : "", toString(SignedMath.abs(value)));
	}

	/**
	 * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
	 */
	function toHexString(uint256 value) internal pure returns (string memory) {
		unchecked {
			return toHexString(value, Math.log256(value) + 1);
		}
	}

	/**
	 * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
	 */
	function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
		bytes memory buffer = new bytes(2 * length + 2);
		buffer[0] = "0";
		buffer[1] = "x";
		for (uint256 i = 2 * length + 1; i > 1; --i) {
			buffer[i] = _SYMBOLS[value & 0xf];
			value >>= 4;
		}
		require(value == 0, "Strings: hex length insufficient");
		return string(buffer);
	}

	/**
	 * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
	 */
	function toHexString(address addr) internal pure returns (string memory) {
		return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
	}

	/**
	 * @dev Converts a `bytes` to its ASCII `string` hexadecimal representation with fixed length.
	 */
	function toHexString(bytes memory value, uint256 start, uint256 length) internal pure returns (string memory) {
		uint256 end = start + length;
		require(end <= value.length, "Strings: invalid params");
		bytes memory buffer = new bytes(2 * length);
		for (uint256 i = start; i < end; i++) {
			uint8 v = uint8(value[i]);
			buffer[2 * (i - start)] = _SYMBOLS[(v >> 4)];
			buffer[2 * (i - start) + 1] = _SYMBOLS[v % 16];
		}
		return string(buffer);
	}

	/**
	 * @dev Returns true if the two strings are equal.
	 */
	function equal(string memory a, string memory b) internal pure returns (bool) {
		return keccak256(bytes(a)) == keccak256(bytes(b));
	}

	function toFixed(uint256 value, uint256 decimals, uint256 reserved) internal pure returns (string memory) {
		uint256 base = 10 ** decimals;
		uint256 integer = value / base;
		uint256 fractional = value % base;
		if (fractional == 0) {
			return toString(integer);
		}
		uint256 length = Math.log10(fractional) + 1;
		require(decimals >= length, "NumberLib: invalid fractional");
		uint256 padZeroLength = decimals - length;
		if (padZeroLength >= reserved) {
			return toString(integer);
		}
		string memory temp = toString(matchFractionalToReserved(fractional, reserved - padZeroLength));
		return string.concat(toString(integer), ".", zeros(padZeroLength), temp);
	}

	function matchFractionalToReserved(uint256 value, uint256 len) internal pure returns (uint256) {
		value = trimZeros(value);
		while (value != 0 && Math.log10(value) + 1 > len) {
			value /= 10;
			value = trimZeros(value);
		}
		return value;
	}

	function trimZeros(uint256 value) internal pure returns (uint256) {
		while (value != 0 && value % 10 == 0) {
			value /= 10;
		}
		return value;
	}

	function zeros(uint256 length) internal pure returns (string memory str) {
		while (length > 0) {
			str = string.concat(str, "0");
			length--;
		}
	}
}
