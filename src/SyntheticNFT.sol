// SPDX-License-Identifier: MIT
// synthetic NFT collection contract

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @notice Implementation of synthetic NFT function based on openzepping's ERC721 contract.
 * player can synthesize a new NFT in this contract from existing NFT collection.
 * player has to pay some ether for synthesizing, he can refund the ether when burning the 
 * new NFT.
 */
contract SyntheticNFT is ERC721Enumerable, ReentrancyGuard, Ownable, Pausable {

  uint256 public constant _mintPrice = 0.1 ether;
  // 10% percent
  uint256 public constant _burnDiscount = 10; 
  // 5% percent
  uint256 public constant _transferDiscount = 5;

  // from new tokenId to original contract address
  mapping(uint256 => address) public _tokenId2contract;
  
  // from new tokenId to original tokenId
  mapping(uint256 => uint256) public _tokenId2oriTokenId;

  // we only allow unique original existing NFT.
  mapping(bytes32 => uint256) public _uniques;
  
  // for tokenId to ether balance which change when mint, transfer
  mapping(uint256 => uint256) public _etherBalances;

  // 5% commission 
  uint256 public _commission;

  // new tokenId for next NFT
  uint256 public _nextTokenId;

  event Mint(address indexed to, address indexed contractAdddr, uint256 indexed tokenId, uint256 newTokenId, uint256 amount);
  event Refund(uint256 indexed tokenId, uint256 amount, uint256 discount);
  event TransferDiscount(address indexed from, address indexed to, uint256 indexed tokenId, uint256 amount, uint256 discount);
  event CommissionWithdrawn(uint256 amount);

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    _nextTokenId = 1;
  }

  /**
   * @notice Get the delegated original URI from new generated tokenId.
   * @param tokenId The id of the token.
   */
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "SyntheticNFT: URI query for nonexistent token");
    string memory uri = IERC721Metadata(_tokenId2contract[tokenId]).tokenURI(_tokenId2oriTokenId[tokenId]);
    return uri;
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
    ) payable external nonReentrant returns (uint256) {
    require(msg.value == _mintPrice, "SyntheticNFT: invalid price");

    uint curr;
    bytes32 hash = keccak256(abi.encode(contractAddr, tokenId));
    if(_uniques[hash] > 0) {
      curr = _uniques[hash];
      require(!_exists(curr), "SyntheticNFT: already minted");
    } else {
      curr = _nextTokenId++;
      _uniques[hash] = curr;
    }

    _tokenId2contract[curr] = contractAddr;
    _tokenId2oriTokenId[curr] = tokenId;

    _etherBalances[curr] += _mintPrice;

    _mint(to, curr);

    emit Mint(to, contractAddr, tokenId, curr, _mintPrice);
    return curr;
  }  

  /**
   * @notice Refund token and return the mint price to the token owner.
   * @param tokenId The id of the token to refund.
   */
  function refund(uint256 tokenId) external nonReentrant {
    require(ownerOf(tokenId) == msg.sender, "SyntheticNFT: must own token");
    _burn(tokenId);

    uint256 discount = _etherBalances[tokenId] * _burnDiscount / 100;
    uint256 amount = _etherBalances[tokenId] - discount;

    _commission += discount;

    delete _etherBalances[tokenId];

    // Refund the token owner 95% of the mint price.
    payable(msg.sender).transfer(amount);

    emit Refund(tokenId, amount, discount);
  }

  /**
   * owner withdraw commission from contract
   */
  function withdrawCommission() external nonReentrant onlyOwner returns (uint256) {
    uint256 amount = _commission;
    _commission = 0;
    payable(msg.sender).transfer(amount);
    emit CommissionWithdrawn(amount);
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
    if(from != to && from != address(0) && to != address(0)) {
      uint256 amount = _etherBalances[tokenId];
      uint256 discount = _etherBalances[tokenId] * _transferDiscount / 100;

      _etherBalances[tokenId] -= discount;
      _commission += discount; 
      emit TransferDiscount(from, to, tokenId, amount, discount);
    }
  }

}



