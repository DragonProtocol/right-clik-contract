// SPDX-License-Identifier: MIT
// synthetic NFT collection contract

/*

``````````````````$$$$$
`````````````$$$$$$´´´´$$$$$$
``````````$$$´´´´´´´´´´´´´´´´$$$
````````$`$$´´´´´´´´´´´´´´´´´´´´$$
```````$´$$$´´´´´´´´´´´´´´´´´´´´´$$$$
`````$´´$$$$´´´´´´´´´´´´´´´´´´´´´´´´´´$
````$´´$$$$$´´´´´´´´´´$$$$$$$´´´´´´´´´$$
```$´´´$$$$$$$´´´$$$$$$$$$$$$$$$$$´´´´´$$
``$´´´´$$$$$$$$$$$$$$$$$$$$$$$$$$$$$´´´´$$
`$´´´´´´$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$´´$
`$´´´´´´$$$$$$$$$$$´´´´$$$$$$$$$$$$$$$$$$$
$´´´´´´´´$$$$$$$$´´´´´´´´$$$$$$$´´´´´´´´$$
$´´´´´´´´´$$$$$$´´´´´´´´´´$$$$´´´´´´´´´´´$
`$´´´´´´´´´$$$$$´´´´´´´´´´$$$´´´´´´´´´´´$
`$´´´´´´´´´´$$$$$´´´´´´´´$$$$´´´´´´´´´´´$
`$´´´´´´´´´´´$$$$$$´´´´$$$$$´´´´´´´´´´´$$
``$´´´´´´´´´´´$$$$$$$$$$$$$$´´´´´´´´´´´$
``$$´´´´´´´´´´´´$$$$$$$$$$$$´´´´´´´´´´$$
```$$´´´´´´´´´´´´$$$$$$$$$$´´´´´´´´´´$$
````$´´´´´´´´´´´´$$$$$$$$$´´´´´´´´´´´$
`````$´´´´´´´´´´´$$$$$$$$´´´´´´´´´´´$
``````$$´´´´´´´´´$$$$$$´´´´´´´´´´´$$
````````$$´´´´´´$$$$$´´´´´´´´´´´$$
``````````$$$´$$$$´´´´´´´´´´´$$$
`````````````$$$$$´´´´´´$$$$$
``````````````````$$$$$$

*/

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";

/**
 * @title A synthetic tool NFT contract
 * @author jack.liu
 *
 * @notice Implementation of synthetic NFT function based on openzepping's ERC721 contract.
 * player can synthesize a new NFT in this contract from existing NFT collection.
 * player has to pay some ether for synthesizing, he can refund the ether when burning the 
 * new NFT.
 *
 * @dev the existing NFT or ERC1155 contract must implement ERC165 standard.
 */
contract SyntheticNFT is ERC721Enumerable, ReentrancyGuard, Ownable, Pausable {

  /// lowest price paid for mint 
  uint256 public constant _mintPrice = 0.1 ether;

  /// 10% percent of leftover ether will be charged when burning.
  uint256 public constant _burnDiscount = 10; 

  /// 5% percent of leftover ether will be charged when transfering.
  uint256 public constant _transferDiscount = 5;

  /// mapping from new tokenId to original contract address
  mapping(uint256 => address) public _tokenId2contract;
  
  /// mapping from new tokenId to original tokenId
  mapping(uint256 => uint256) public _tokenId2oriTokenId;

  /// used to keep unique original existing NFT.
  mapping(bytes32 => uint256) public _uniques;
  
  /// mapping from tokenId to ether balance which change when mint, transfer
  mapping(uint256 => uint256) public _etherBalances;

  /// accumulated commission from transfering and burning
  uint256 public _commission;

  /// new tokenId for next NFT
  uint256 public _nextTokenId;

  /// constant interface signator for ERC721
  bytes4 constant internal INTERFACE_SIGNATURE_ERC721 = 0x80ac58cd;

  /// constant interface signator for ERC1155
  bytes4 constant internal INTERFACE_SIGNATURE_ERC1155 = 0xd9b67a26;

  /**
   * @dev Emitted when `newTokenId` token is minted to `to` based on `contractAddr` and `tokenId`, msg.sender will pay `amount` ether.
   */
  event Mint(address indexed to, address indexed contractAdddr, uint256 indexed tokenId, uint256 newTokenId, uint256 amount);

  /**
   * @dev Emitted when `tokenId` token is burnt with commission of `discount` ether charged, `amount` is leftover ether before burn.
   */
  event Refund(uint256 indexed tokenId, uint256 amount, uint256 discount);

  /**
   * @dev Emitted when `tokenId` token is transfred from `from` to `to` with commission of 'discount' ether charged, `amount` is leftover ether before burn.
   */
  event TransferDiscount(address indexed from, address indexed to, uint256 indexed tokenId, uint256 amount, uint256 discount);

  /**
   * @dev Emitted when owner withdraw `amount` ether commitssion.
   */
  event CommissionWithdrawn(uint256 amount);


  /**
   * @dev contruct a new ERC721 collection
   * @param name NFT collection name
   * @param symbol NFT collection symbol
   */
  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    _nextTokenId = 1;
  }

  /**
   * @dev Get the delegated original URI from new generated tokenId.
   * @param tokenId The id of the token.
   * @return string memory url of originial NFT 
   */
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "SyntheticNFT: URI query for nonexistent token");

    IERC165 tokenInterface = IERC165(_tokenId2contract[tokenId]);

    if(tokenInterface.supportsInterface(INTERFACE_SIGNATURE_ERC1155)) {
      return IERC1155MetadataURI(_tokenId2contract[tokenId]).uri(_tokenId2oriTokenId[tokenId]);
    }
    if(tokenInterface.supportsInterface(INTERFACE_SIGNATURE_ERC721)) {
      return IERC721Metadata(_tokenId2contract[tokenId]).tokenURI(_tokenId2oriTokenId[tokenId]);
    }

    require(false, "only support 721 or 1155 token");
    return "";
  }

  /**
   * @dev check if token exist.
   * @param tokenId The id of the token.
   * @return bool 
   */
  function exists(uint256 tokenId) public view returns (bool) {
    return _exists(tokenId);
  }

  /**
   * @dev check original nft or erc1155 has been copied in this contract,
   * @param contractAddr contract address of existing NFT collection, must implement tokenURI function
   * @param tokenId tokenId of existing NFT
   * @return bool
   */
  function copied(address contractAddr, uint256 tokenId) public view returns (bool) {
    bytes32 hash = keccak256(abi.encode(contractAddr, tokenId));
    return _uniques[hash] > 0 && _exists(_uniques[hash]);
  }

  /**
   * @dev get new tokenId for original nft contract address and tokenId,
   * @param contractAddr contract address of existing NFT collection, must implement tokenURI function
   * @param tokenId tokenId of existing NFT
   * @return uint256 new tokenId
   */
  function getTokenIdFromOriginal(address contractAddr, uint256 tokenId) public view returns (uint256) {
    bytes32 hash = keccak256(abi.encode(contractAddr, tokenId));
    uint256 newTokenId = _uniques[hash];
    return _exists(newTokenId) ? newTokenId : 0;
  }

  /**
   * @dev synthetic new NFT from existing NFT, in this contract tokenURI() will return the original URI,
   * every mint will charge some ether.
   *
   * @param to owner of new synthetic Token
   * @param contractAddr contract address of existing NFT collection, must implement tokenURI function
   * @param tokenId tokenId of existing NFT
   * @return uint256 minted new tokenId of this NFT collection
   */
  function mint(
    address to, 
    address contractAddr, 
    uint256 tokenId
    ) payable external nonReentrant returns (uint256) {
    require(msg.value >= _mintPrice, "SyntheticNFT: invalid price");

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

    _etherBalances[curr] += msg.value;

    _mint(to, curr);

    emit Mint(to, contractAddr, tokenId, curr, msg.value);
    return curr;
  }  

  /**
   * @dev burn token and return the mint price to the token owner.
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
   * @dev owner withdraw commission from contract
   */
  function withdrawCommission() external nonReentrant onlyOwner returns (uint256) {
    uint256 amount = _commission;
    _commission = 0;
    payable(msg.sender).transfer(amount);
    emit CommissionWithdrawn(amount);
    return amount;
  }

  /**
   * @dev Returns all the token ids owned by a given address
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
   * @dev When the contract is paused, all token transfers are prevented in case of emergency.
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



