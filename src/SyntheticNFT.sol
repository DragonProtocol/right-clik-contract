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

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "erc721a/contracts/ERC721A.sol";

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
contract SyntheticNFT is ERC721A, ReentrancyGuard, Ownable, Pausable {

  /// mapping from new tokenId to original contract address
  mapping(uint256 => address) public _tokenIdToContract;
  
  /// mapping from new tokenId to original tokenId
  mapping(uint256 => uint256) public _tokenIdToOriTokenId;

  /// used to keep unique original existing NFT.
  mapping(address => mapping(uint256 => uint256)) _uniques;
  
  /// mapping from tokenId to ether balance which change when mint, transfer
  mapping(uint256 => uint256) public _etherBalances;

  /// constant interface signator for ERC721
  bytes4 constant internal INTERFACE_SIGNATURE_ERC721 = 0x80ac58cd;

  /// constant interface signator for ERC1155
  bytes4 constant internal INTERFACE_SIGNATURE_ERC1155 = 0xd9b67a26;

  /**
   * @dev Emitted when `newTokenId` token is minted to `to` based on `contractAddr` and `tokenId`, msg.sender will pay `amount` ether.
   */
  event Mint(address indexed to, address indexed contractAdddr, uint256 indexed tokenId, uint256 newTokenId, uint256 amount);

  /**
   * @dev Emitted when `tokenId` token is burnt, `amount` is leftover ether before burn.
   */
  event Refund(uint256 indexed tokenId, uint256 amount);

  /**
   * @dev contruct a new ERC721 collection
   * @param name NFT collection name
   * @param symbol NFT collection symbol
   */
  constructor(string memory name, string memory symbol) ERC721A(name, symbol) {
  }

  /**
   * @dev Get the delegated original URI from new generated tokenId.
   * @param tokenId The id of the token.
   * @return string memory url of originial NFT 
   */
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "SyntheticNFT: URI query for nonexistent token");

    IERC165 tokenInterface = IERC165(_tokenIdToContract[tokenId]);

    if(tokenInterface.supportsInterface(INTERFACE_SIGNATURE_ERC1155)) {
      return IERC1155MetadataURI(_tokenIdToContract[tokenId]).uri(_tokenIdToOriTokenId[tokenId]);
    }
    if(tokenInterface.supportsInterface(INTERFACE_SIGNATURE_ERC721)) {
      return IERC721Metadata(_tokenIdToContract[tokenId]).tokenURI(_tokenIdToOriTokenId[tokenId]);
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
   * @return uint256 zero means original token is not copied;
   */
  function getTokenId(address contractAddr, uint256 tokenId) public view returns (uint256) {
    return _uniques[contractAddr][tokenId];
  }

  /**
    * override To change the starting tokenId, .
    */
  function _startTokenId() internal pure override returns (uint256) {
      return 1;
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
    require(_uniques[contractAddr][tokenId] == 0, "SyntheticNFT: already minted");

    uint curr = _currentIndex;
    _uniques[contractAddr][tokenId] = curr;

    _tokenIdToContract[curr] = contractAddr;
    _tokenIdToOriTokenId[curr] = tokenId;

    if(msg.value > 0) {
      _etherBalances[curr] += msg.value;
    }

    _mint(to, 1);

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

    uint256 amount = _etherBalances[tokenId];
    address contractAddr = _tokenIdToContract[tokenId];
    uint256 oriTokenId = _tokenIdToOriTokenId[tokenId];

    delete _uniques[contractAddr][oriTokenId];
    delete _tokenIdToContract[tokenId];
    delete _tokenIdToOriTokenId[tokenId];
    delete _etherBalances[tokenId];

    // Refund the token owner the mint price.
    if(amount > 0) {
      payable(msg.sender).transfer(amount);
    }

    emit Refund(tokenId, amount);
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
  function _beforeTokenTransfers(
    address from,
    address to,
    uint256 startTokenId,
    uint256 quantity
  ) internal override whenNotPaused {
    super._beforeTokenTransfers(from, to, startTokenId, quantity);
  }

}



