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
	uint64 public fundingStart;
	uint64 public fundingEnd;

	// uint32 public constant maxFree = 500;
	uint32 public constant maxFree = 10;

	// uint32 public maxPhaseOne = 3500;
	uint32 public maxPhaseOne = 5;

	// uint32 public constant maxPhaseTwo = 5999;
	uint32 public constant maxPhaseTwo = 5;
	uint32 public freeSold = 0;
	uint32 public phaseOneSold = 0;
	uint32 public phaseTwoSold = 0;
	uint32 internal nonce;
	bool internal phaseUpdated;
	uint64 public constant phaseOneFee = 5e15;
	uint64 public constant phaseTwoFee = 1e16;

	IMossyDescriptor internal descriptor;

	mapping(uint256 => uint256) public token2Metas;

	mapping(address => bool) internal wl;

	enum Phase {
		FreeNotStarted,
		FreeStarted,
		FreeEndedAndFundingNotStarted,
		FundingStarted,
		FudingEnded
	}

	/// @dev This event emits when the metadata of a token is changed.
	/// So that the third-party platforms such as NFT market could
	/// timely update the images and related attributes of the NFT.
	event MetadataUpdate(uint256 _tokenId);

	/// @dev This event emits when the metadata of a range of tokens is changed.
	/// So that the third-party platforms such as NFT market could
	/// timely update the images and related attributes of the NFTs.
	event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

	modifier onlyHoldOne() {
		require(balanceOf(msg.sender) == 0, "One can only hold one token");
		_;
	}

	modifier mintingEnded() {
		require(getPhase() == Phase.FudingEnded, "Minting is not ending");
		_;
	}

	function initialize(address admin, uint64 _freeStart, uint64 _freeEnd, uint64 _fundingStart, uint64 _fundingEnd) external initializer {
		require(_freeStart >= block.timestamp);
		require(_freeStart < _freeEnd);
		require(_freeEnd <= _fundingStart);
		require(_fundingStart < _fundingEnd);
		_transferOwnership(admin);
		maxPhaseOne = 3500;
		freeStart = _freeStart;
		freeEnd = _freeEnd;
		fundingStart = _fundingStart;
		fundingEnd = _fundingEnd;
	}

	function updateTime(uint64 _freeStart, uint64 _freeEnd, uint64 _fundingStart, uint64 _fundingEnd) external onlyOwner {
		freeStart = _freeStart;
		freeEnd = _freeEnd;
		fundingStart = _fundingStart;
		fundingEnd = _fundingEnd;
	}

	function open(IMossyDescriptor _descriptor) external onlyOwner {
		require(getPhase() == Phase.FudingEnded || nonce == maxFree + maxPhaseOne + maxPhaseTwo - 1, "Minting is not ended");
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
			return Phase.FreeNotStarted;
		}

		if (block.timestamp < freeEnd) {
			return Phase.FreeStarted;
		}

		if (block.timestamp < fundingStart) {
			return Phase.FreeEndedAndFundingNotStarted;
		}

		if (block.timestamp < fundingEnd) {
			return Phase.FundingStarted;
		}

		return Phase.FudingEnded;
	}

	function mint() external payable onlyHoldOne nonReentrant {
		Phase phase = getPhase();
		if (phase == Phase.FreeNotStarted) {
			revert("Free minting is not open");
		}

		if (phase == Phase.FreeEndedAndFundingNotStarted) {
			revert("Funding minting is not open");
		}

		if (phase == Phase.FudingEnded) {
			revert("Minting is closed");
		}

		address minter = msg.sender;
		if (phase == Phase.FreeStarted) {
			// free mint
			require(wl[minter], "Caller is not in white list");
			_freeMint(minter);
		}

		if (phase == Phase.FundingStarted) {
			// funding mint
			_fundingMint(minter);
		}
		nonce++;
	}

	function _freeMint(address minter) internal {
		require(balanceOf(minter) == 0, "One can hold one token");
		require(freeSold < maxFree, "Free minting has been sold out");
		freeSold++;
		_mintToken(minter, nonce);
	}

	function _fundingMint(address minter) internal {
		if (!phaseUpdated) {
			phaseUpdated = true;
			maxPhaseOne = maxPhaseOne + maxFree - freeSold;
		}
		if (phaseOneSold < maxPhaseOne) {
			require(msg.value >= phaseOneFee, "insufficient funds to mint");
			if (msg.value > phaseOneFee) {
				_transferFunds(minter, msg.value - phaseOneFee, "transfer back failed at phase one");
			}
			phaseOneSold++;
		} else if (phaseTwoSold < maxPhaseTwo) {
			require(msg.value >= phaseTwoFee, "insufficient funds to mint");
			if (msg.value > phaseTwoFee) {
				_transferFunds(minter, msg.value - phaseTwoFee, "transfer back failed at phase two");
			}
			phaseTwoSold++;
		} else {
			revert("All tokens sold out");
		}
		_mintToken(minter, nonce);
	}

	function _mintToken(address minter, uint256 _nonce) internal {
		uint256 metaId = _getMetaId(minter, _nonce, block.number);
		token2Metas[_nonce] = metaId;
		_mint(minter, _nonce);
	}

	function _getMetaId(address minter, uint256 _nonce, uint256 _blockNumber) internal pure returns (uint256) {
		return uint256(keccak256(abi.encodePacked(minter, _nonce, _blockNumber)));
	}

	function tokenURI(uint256 id) public view override returns (string memory) {
		Phase phase = getPhase();
		if (phase != Phase.FudingEnded) {
			return "ipfs://bafkreif3uzwdn52tasg7gbb5izsx6p32qbm5zqhtw7n3v4mhheojiuiiqq";
		}
		require(address(descriptor) != address(0), "Mossy: No NFT descriptor");
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

	function transferFrom(address from, address to, uint256 tokenId) public override(ERC721Upgradeable, IERC721Upgradeable) mintingEnded {
		super.transferFrom(from, to, tokenId);
	}

	function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override(ERC721Upgradeable, IERC721Upgradeable) mintingEnded {
		super.safeTransferFrom(from, to, tokenId);
	}

	function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override(ERC721Upgradeable, IERC721Upgradeable) mintingEnded {
		super.safeTransferFrom(from, to, tokenId, data);
	}

	receive() external payable {}
}
