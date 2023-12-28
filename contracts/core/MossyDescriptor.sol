// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "../libraries/Strings.sol";

contract MossyDescriptor {
	string public rootURI;
	uint32[10] internal _pcts = [12, 12, 12, 12, 12, 12, 12, 3, 5, 8];
	uint8[6] internal _pctDistribs = [40, 40, 40, 40, 48, 48];

	constructor(string memory _rootURI) {
		rootURI = _rootURI;
	}

	function getPartOf(uint256 metaId, uint8 index) public view returns (uint8) {
		(uint256 n, uint256 max) = getN(metaId, index);
		return getPart(n, max);
	}

	function getN(uint256 metaId, uint8 index) public view returns (uint256 n, uint256 max) {
		require(index < _pctDistribs.length, "index out of range");
		for (uint8 k = uint8(_pctDistribs.length - 1); k > index; k--) {
			metaId = metaId >> (_pctDistribs[k]);
		}
		max = (1 << _pctDistribs[index]) - 1;
		n = metaId & max;
	}

	function getPart(uint256 n, uint256 max) public view returns (uint8) {
		uint256 floor = 0;
		for (uint8 i = 0; i < _pcts.length; i++) {
			uint256 p = (max * _pcts[i]) / 100;
			if (n >= floor && n < floor + p) {
				return i;
			}
			floor = floor + p;
		}
		return uint8(_pcts.length - 1);
	}

	function getImageData(uint256 metaId) public view returns (string memory data) {
		string memory head = '<svg width="1000" height="1000" viewBox="0 0 1000 1000" fill="none" xmlns="http://www.w3.org/2000/svg">';
		string memory tail = "</svg>";
		data = head;
		for (uint8 i = 0; i < _pctDistribs.length; i++) {
			string memory component = Strings.toString(i);
			string memory part = Strings.toString(getPartOf(metaId, i));
			data = string.concat(data, '<image href="', rootURI, "/", component, "/", part, '.svg" />');
		}
		data = string.concat(data, tail);
	}
}
