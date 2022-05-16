// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "ds-test/test.sol";
import "src/SyntheticNFT.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";


contract GameItem is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("GameItem", "ITM") {}

    function awardItem(address player, string memory tokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }
}

interface CheatCodes {
  function prank(address) external;
}

contract SyntheticNFTTest is DSTest {

    SyntheticNFT _syntheticNFT;
    GameItem _gameItem;
    ERC1155  _erc1155;
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    uint256 public constant _price = 0.0005 ether;

    function setUp() public {
        _syntheticNFT = new SyntheticNFT("synthetic NFT", "SNFT");
        _gameItem = new GameItem();
        _erc1155 = new ERC1155("http://bbb.json");
    }

    fallback() external payable {}
    receive() external payable {}

    function testTokenURI() public {
        string memory uri1 = "http://aaa.json";
        uint tokenId1 = _gameItem.awardItem(address(0x1), uri1);
        uint newTokenId1 = _syntheticNFT.mint{value: _price}(address(0x3), address(_gameItem), tokenId1);
        assertTrue(keccak256(abi.encode(_syntheticNFT.tokenURI(newTokenId1))) == keccak256(abi.encode(uri1)), "tokenURI failed");
    }

    function testERC1155TokenURI() public {
        string memory uri1 = "http://bbb.json";
        uint tokenId1 = 1;
        uint newTokenId1 = _syntheticNFT.mint{value: _price}(address(0x3), address(_erc1155), tokenId1);
        assertTrue(keccak256(abi.encode(_syntheticNFT.tokenURI(newTokenId1))) == keccak256(abi.encode(uri1)), "tokenURI failed");
    }

    function testMint() public {
        string memory uri1 = "http://aaa.json";
        uint tokenId1 = _gameItem.awardItem(address(0x1), uri1);
        uint256 preBalance = address(_syntheticNFT).balance;
        _syntheticNFT.mint{value: _price}(address(0x3), address(_gameItem), tokenId1);
        uint256 postBalance = address(_syntheticNFT).balance;
        assertEq(preBalance + _price, postBalance);
    }

    function testRefund() public {
        string memory uri1 = "http://aaa.json";
        uint tokenId1 = _gameItem.awardItem(address(0x1), uri1);
        uint newTokenId1 = _syntheticNFT.mint{value: _price}(address(0x3), address(_gameItem), tokenId1);
        cheats.prank(address(0x3));
        _syntheticNFT.refund(newTokenId1);
        assertEq(address(0x3).balance, _price);
    }

    function testTransfer() public {
        string memory uri1 = "http://aaa.json";
        uint tokenId1 = _gameItem.awardItem(address(0x1), uri1);
        uint newTokenId1 = _syntheticNFT.mint{value: _price}(address(0x3), address(_gameItem), tokenId1);
        cheats.prank(address(0x3));
        _syntheticNFT.transferFrom(address(0x3), address(0x4), newTokenId1);
        assertEq(_syntheticNFT._etherBalances(newTokenId1), _price);
    }

    function testFailMintRepeatedNFT() public {
        uint tokenId1 = _gameItem.awardItem(address(0x1), "http://aaa.json");
        _syntheticNFT.mint{value: _price}(address(0x3), address(_gameItem), tokenId1);
        _syntheticNFT.mint{value: _price}(address(0x4), address(_gameItem), tokenId1);
    }

    function testFailMintWithZeroValue() public {
        uint tokenId1 = _gameItem.awardItem(address(0x1), "http://aaa.json");
        uint newTokenId1 = _syntheticNFT.mint(address(0x3), address(_gameItem), tokenId1);
        cheats.prank(address(0x3));
        _syntheticNFT.refund(newTokenId1);
    }

    function testFailRefundTwice() public {
        uint tokenId1 = _gameItem.awardItem(address(0x1), "http://aaa.json");
        uint newTokenId1 = _syntheticNFT.mint{value: _price}(address(0x3), address(_gameItem), tokenId1);
        _syntheticNFT.refund(newTokenId1);
        _syntheticNFT.refund(newTokenId1);
    }

    function testFailMintWithLowValue() public {
        uint tokenId1 = _gameItem.awardItem(address(0x1), "http://aaa.json");
        uint newTokenId1 = _syntheticNFT.mint{value: 0.0001 ether}(address(0x3), address(_gameItem), tokenId1);
        cheats.prank(address(0x3));
        _syntheticNFT.refund(newTokenId1);
    }

    function testMintWithHighValue() public {
        uint tokenId1 = _gameItem.awardItem(address(0x1), "http://aaa.json");
        uint newTokenId1 = _syntheticNFT.mint{value: 0.01 ether}(address(0x3), address(_gameItem), tokenId1);
        cheats.prank(address(0x3));
        _syntheticNFT.refund(newTokenId1);
        assertEq(address(0x3).balance, 0.01 ether);
    }
    
    function testBondingCurvePrice() public {
        uint m = 1 * 10**8;
        uint base = _price;
        uint tokenId1 = _gameItem.awardItem(address(0x1), "http://aaa.json");
        uint tokenId2 = _gameItem.awardItem(address(0x1), "http://bbb.json");
        uint tokenId3 = _gameItem.awardItem(address(0x1), "http://ccc.json");

        uint price1 = _syntheticNFT.calcMintPrice();
        assertEq(price1, base);
        _syntheticNFT.mint{value: price1}(address(0x3), address(_gameItem), tokenId1);

        uint price2 = _syntheticNFT.calcMintPrice();
        assertEq(price2, base + m*1*1);
        _syntheticNFT.mint{value: price2}(address(0x3), address(_gameItem), tokenId2);

        uint price3 = _syntheticNFT.calcMintPrice();
        assertEq(price3, base + m*2*2);
        uint newTokenId3 = _syntheticNFT.mint{value: price3}(address(0x3), address(_gameItem), tokenId3);

        uint price4 = _syntheticNFT.calcMintPrice();
        assertEq(price4, base + m*3*3);

        cheats.prank(address(0x3));
        _syntheticNFT.refund(newTokenId3);        
        
        uint price5 = _syntheticNFT.calcMintPrice();
        assertEq(price5, base + m*2*2);
    }
}

