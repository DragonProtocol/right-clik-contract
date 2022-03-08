// SPDX-License-Identifier: MIT
// synthetic NFT collection contract

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @notice Implementation of synthetic NFT function based on openzepping's ERC721 contract.
 * player can synthesize a new NFT in this contract from existing NFT collection.
 * player has to pay some ether for synthesizing, he can refund the ether when burning the 
 * new NFT.
 */
contract SyntheticNFT is ERC721Enumerable, ReentrancyGuard, Ownable, Pausable {
  using ECDSA for bytes32;
  using Strings for uint256;
  using Counters for Counters.Counter;
  
  Counters.Counter private _tokenIdTracker;

  uint256 public constant _price = 0.01 ether;

  // from new tokenId to original URI
  mapping(uint256 => string) public _uris;
  // we only allow unique original existing NFT.
  mapping(bytes32 => bool) public _uniques;
  
  // used to recycle tokenIds when mint and burn
  uint256 [] private _freeSlots;

  // 5% commission 
  uint256 public _commission;

  event Mint(address indexed to, address indexed contractAdddr, uint256 indexed tokenId, uint256 newTokenId, string uri);
  event Refund(uint256 indexed tokenId, uint256 amount);

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    // Start token IDs at 1
    _tokenIdTracker.increment();
    // create array for tokenId's free slots
    _freeSlots = new uint256[](0);
  }

  /**
   * @notice Get the delegated original URI from new generated tokenId.
   * @param tokenId The id of the token.
   */
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "URI query for nonexistent token");
    return _uris[tokenId];
  }

  /**
   * @notice synthetic new NFT from existing NFT, in this contract tokenURI() will return the original URI,
   * every mint will charge some ether.
   * @param to owner of new synthetic Token
   * @param contractAddr contract address of existing NFT collection, must implement tokenURI function
   * @param tokenId tokenId of existing NFT
   */
  function mint(
    address to, 
    address contractAddr, 
    uint256 tokenId
    ) payable external returns (uint256) {
    require(msg.value == _price, "SyntheticNFT: invalid price");

    bytes32 hash = keccak256(abi.encode(contractAddr, tokenId));
    require(_uniques[hash] == false, "SyntheticNFT: repeated NFT");
    _uniques[hash] = true;

    uint curr = _tokenIdTracker.current();
    bool useSlot = (_freeSlots.length > 0);

    if(useSlot) {
      curr = _freeSlots[_freeSlots.length-1];
      _freeSlots.pop();
    }

    string memory uri = IERC721Metadata(contractAddr).tokenURI(tokenId);
    _uris[curr] = uri;
    
    _mint(to, curr);
    if(!useSlot) {
      _tokenIdTracker.increment();
    }

    emit Mint(to, contractAddr, tokenId, curr, uri);

    return curr;
  }  

  /**
   * @notice Refund token and return the mint price to the token owner.
   * @param tokenId The id of the token to refund.
   */
  function refund(uint256 tokenId) external nonReentrant {
    require(ownerOf(tokenId) == msg.sender, "SyntheticNFT: must own token");
    _burn(tokenId);
    _freeSlots.push(tokenId);

    uint256 amount = _price * 95 / 100;
    _commission += _price * 5 / 100;

    // Refund the token owner 95% of the mint price.
    payable(msg.sender).transfer(amount);

    emit Refund(tokenId, amount);
  }

  /**
   * owner withdraw commission from contract
   */
  function withdrawCommission() external nonReentrant onlyOwner returns (uint256) {
    uint256 amount = _commission;
    _commission = 0;
    payable(msg.sender).transfer(amount);
    return amount;
  }

  /**
   * Returns all the token ids owned by a given address
   */
  function ownedTokensByAddress(address owner) external view returns (uint256[] memory)
  {
    uint256 totalTokensOwned = balanceOf(owner);
    uint256[] memory allTokenIds = new uint256[](totalTokensOwned);
    for (uint256 i = 0; i < totalTokensOwned; i++) {
      allTokenIds[i] = (tokenOfOwnerByIndex(owner, i));
    }
    return allTokenIds;
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  /**
   * When the contract is paused, all token transfers are prevented in case of emergency.
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override whenNotPaused {
    super._beforeTokenTransfer(from, to, tokenId);
  }

}



