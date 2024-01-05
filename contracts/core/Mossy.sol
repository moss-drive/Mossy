// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "../interfaces/IMossyDescriptor.sol";
import "../libraries/Strings.sol";

contract Mossy is ERC721EnumerableUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
	uint64 public freeStart;
	uint64 public freeEnd;

	uint32 public devReserve = 500;

	// uint32 public constant MAXFREE = 300;
	uint32 public constant MAXFREE = 10;

	// uint32 public maxPhaseOne = 3199;
	uint32 public maxPhaseOne = 5;

	// uint32 public constant MAXPHASETWO = 6000;
	uint32 public constant MAXPHASETWO = 5;
	uint32 public freeSold;
	uint32 public phaseOneSold;
	uint32 public phaseTwoSold;
	uint32 internal nonce;
	bool internal phaseUpdated;
	uint64 public constant phaseOneFee = 5e15;
	uint64 public constant phaseTwoFee = 1e16;

	uint32 internal totalSales;

	IMossyDescriptor internal descriptor;

	uint32 internal constant MAXSALEPERADDR = 5;

	mapping(uint256 => uint256) public token2Metas;

	mapping(address => bool) internal wl;
	mapping(address => uint32) public sales;

	enum Phase {
		NotStarted,
		FreeStarted,
		FundingStarted,
		SoldOut
	}

	/// @dev This event emits when the metadata of a token is changed.
	/// So that the third-party platforms such as NFT market could
	/// timely update the images and related attributes of the NFT.
	event MetadataUpdate(uint256 _tokenId);

	/// @dev This event emits when the metadata of a range of tokens is changed.
	/// So that the third-party platforms such as NFT market could
	/// timely update the images and related attributes of the NFTs.
	event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

	function initialize(address admin, uint64 _freeStart, uint64 _freeEnd) external initializer {
		require(_freeStart >= block.timestamp);
		require(_freeStart < _freeEnd);
		_transferOwnership(admin);
		devReserve = 500;
		maxPhaseOne = 3500;
		totalSales = MAXFREE + maxPhaseOne + MAXPHASETWO;
		freeStart = _freeStart;
		freeEnd = _freeEnd;
	}

	function updateTime(uint64 _freeStart, uint64 _freeEnd) external onlyOwner {
		freeStart = _freeStart;
		freeEnd = _freeEnd;
	}

	function devMint(address to, uint32 amount) external onlyOwner {
		require(devReserve >= amount, "Mossy: No reserve for dev");
		for (uint256 i = 0; i < amount; i++) {
			_mintToken(to);
		}
		devReserve = devReserve - amount;
	}

	function mint() external payable nonReentrant {
		Phase phase = getPhase();
		if (phase == Phase.NotStarted) {
			revert("free minting is not open");
		}

		if (phase == Phase.SoldOut) {
			revert("all tokens sold out");
		}

		address minter = msg.sender;
		if (phase == Phase.FreeStarted) {
			// free mint
			_freeMint(minter);
		}

		if (phase == Phase.FundingStarted) {
			// funding mint
			_fundingMint(minter);
		}
	}

	function _freeMint(address minter) internal {
		require(balanceOf(minter) == 0, "one can only hold one token");
		require(wl[minter], "caller is not in white list");
		require(freeSold < MAXFREE, "free minting has been sold out");
		freeSold++;
		_mintToken(minter);
	}

	function _fundingMint(address minter) internal {
		require(sales[minter] < MAXSALEPERADDR, "minting exceeds the limit");
		if (!phaseUpdated) {
			phaseUpdated = true;
			maxPhaseOne = maxPhaseOne + MAXFREE - freeSold;
		}
		if (phaseOneSold < maxPhaseOne) {
			require(msg.value >= phaseOneFee, "insufficient funds to mint at phase one");
			if (msg.value > phaseOneFee) {
				_transferFunds(minter, msg.value - phaseOneFee, "transfer back failed at phase one");
			}
			phaseOneSold++;
		} else if (phaseTwoSold < MAXPHASETWO) {
			require(msg.value >= phaseTwoFee, "insufficient funds to mint at phase two");
			if (msg.value > phaseTwoFee) {
				_transferFunds(minter, msg.value - phaseTwoFee, "transfer back failed at phase two");
			}
			phaseTwoSold++;
		} else {
			revert("all tokens sold out");
		}
		sales[minter]++;
		_mintToken(minter);
	}

	function _mintToken(address minter) internal {
		uint256 metaId = _getMetaId(minter, nonce, block.number);
		token2Metas[nonce] = metaId;
		_mint(minter, nonce);
		nonce++;
	}

	function _getMetaId(address minter, uint256 _nonce, uint256 _blockNumber) internal pure returns (uint256) {
		return uint256(keccak256(abi.encodePacked(minter, _nonce, _blockNumber)));
	}

	function open(IMossyDescriptor _descriptor) external onlyOwner {
		require(address(descriptor) == address(0), "desciptor exists");
		descriptor = _descriptor;
		emit BatchMetadataUpdate(0, nonce);
	}

	function updateWL(address[] memory list, bool enabled) external onlyOwner {
		for (uint256 i = 0; i < list.length; i++) {
			wl[list[i]] = enabled;
		}
	}

	function getPhase() public view returns (Phase) {
		if (block.timestamp < freeStart) {
			return Phase.NotStarted;
		}

		if (block.timestamp < freeEnd) {
			return Phase.FreeStarted;
		}

		if (freeSold + phaseOneSold + phaseTwoSold == totalSales) {
			return Phase.SoldOut;
		}

		return Phase.FundingStarted;
	}

	function tokenURI(uint256 id) public view override returns (string memory) {
		if (address(descriptor) == address(0)) {
			return "ipfs://bafkreif3uzwdn52tasg7gbb5izsx6p32qbm5zqhtw7n3v4mhheojiuiiqq";
		}
		string memory name = string.concat("@Mossy-", Strings.toString(id));
		string memory image = descriptor.getImageData(token2Metas[id]);
		string memory json = string(abi.encodePacked('{"name":"', name, '","description":"', name, '","image_data":"', image, '"}'));
		return string.concat("data:application/json;utf8,", json);
	}

	function _transferFunds(address to, uint256 value, string memory message) internal {
		(bool success, ) = to.call{ value: value }("");
		require(success, message);
	}

	function withdraw(IERC20 coin, address to, uint256 value) external onlyOwner {
		if (address(coin) == address(0)) {
			_transferFunds(to, value, "withdraw native coin failed");
		} else {
			coin.transfer(to, value);
		}
	}

	function fundingPhase() public view returns (uint8) {
		if (getPhase() != Phase.FundingStarted) {
			return 0;
		}
		if (phaseOneSold < maxPhaseOne) {
			return 1;
		}
		if (phaseTwoSold < MAXPHASETWO) {
			return 2;
		}
		return 3;
	}

	receive() external payable {}
}
