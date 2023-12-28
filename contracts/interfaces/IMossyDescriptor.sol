// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IMossyDescriptor {
	function getPartOf(uint256 metaId, uint8 index) external view returns (uint256);

	function getN(uint256 metaId, uint8 index) external view returns (uint256 n, uint256 max);

	function getPart(uint256 n, uint256 max) external view returns (uint8);

	function getImageData(uint256 metaId) external view returns (string memory data);
}
