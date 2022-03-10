// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "src/SyntheticNFT.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

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
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    uint256 public constant _price = 0.01 ether;

    function setUp() public {
        // owner = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
        _syntheticNFT = new SyntheticNFT("synthetic NFT", "SNFT");

        _gameItem = new GameItem();
    }

    fallback() external payable {}
    receive() external payable {}

    function testMintRefund() public {
        string memory uri1 = "http://aaa.json";
        string memory uri2 = "http://bbb.json";
        // string memory uri3 = "http://ccc.json";
        // string memory uri4 = "http://ddd.json";

        uint tokenId1 = _gameItem.awardItem(address(0x1), uri1);
        uint tokenId2 = _gameItem.awardItem(address(0x2), uri2);
        // uint tokenId3 = _gameItem.awardItem(address(0x3), uri3);
        // uint tokenId4 = _gameItem.awardItem(address(0x3), uri4);

        uint256 preBalance = address(_syntheticNFT).balance;

        uint newTokenId1 = _syntheticNFT.mint{value: _price}(address(0x3), address(_gameItem), tokenId1);
        uint newTokenId2 = _syntheticNFT.mint{value: _price}(address(0x3), address(_gameItem), tokenId2);

        uint256 postBalance = address(_syntheticNFT).balance;
        assertEq(preBalance + _price + _price, postBalance);

        assertTrue(keccak256(abi.encode(_syntheticNFT.tokenURI(newTokenId1))) == keccak256(abi.encode(uri1)), "tokenURI failed");
        assertTrue(keccak256(abi.encode(_syntheticNFT.tokenURI(newTokenId2))) == keccak256(abi.encode(uri2)), "tokenURI failed");

        uint256 amount = _price * 95 / 100;
        preBalance = address(0x3).balance;

        cheats.prank(address(0x3));
        _syntheticNFT.refund(newTokenId1);

        postBalance = address(0x3).balance;
        assertEq(preBalance + amount, postBalance);

        cheats.prank(address(0x3));
        _syntheticNFT.refund(newTokenId2);

        emit log_named_decimal_uint("contract commission: ", _syntheticNFT._commission(), 18);
        emit log_named_decimal_uint("contract balance before withdrawCommission ", address(_syntheticNFT).balance, 18);

        cheats.prank(address(_syntheticNFT.owner()));
        _syntheticNFT.withdrawCommission();

        emit log_named_decimal_uint("contract balance after  withdrawCommission ", address(_syntheticNFT).balance, 18);
    }
    
    function testFailMintRepeatedNFT() public {
        uint tokenId1 = _gameItem.awardItem(address(0x1), "http://aaa.json");
        _syntheticNFT.mint{value: _price}(address(0x3), address(_gameItem), tokenId1);
        _syntheticNFT.mint{value: _price}(address(0x4), address(_gameItem), tokenId1);
    }

    function testFailMintLowValue() public {
        uint tokenId1 = _gameItem.awardItem(address(0x1), "http://aaa.json");
        _syntheticNFT.mint{value: _price - 1}(address(0x3), address(_gameItem), tokenId1);
    }

    function testFailMintHighValue() public {
        uint tokenId1 = _gameItem.awardItem(address(0x1), "http://aaa.json");
        _syntheticNFT.mint{value: _price + 1}(address(0x3), address(_gameItem), tokenId1);
    }

    function testFailRefundTwice() public {
        uint tokenId1 = _gameItem.awardItem(address(0x1), "http://aaa.json");
        uint newTokenId1 = _syntheticNFT.mint{value: _price}(address(0x3), address(_gameItem), tokenId1);
        _syntheticNFT.refund(newTokenId1);
        _syntheticNFT.refund(newTokenId1);
    }
}

