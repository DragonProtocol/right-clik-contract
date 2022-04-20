
# SyntheticNFT contract


A contract for synthetizing your favourite NFT from NFT market, etc opensea.

## Features

- ERC721 standard implement based on OpenZeppelin contract library
- Can inject Ethers when mint, withdraw Ethers when burn.
- Support ERC1155 token 

[OpenZeppelin Github Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) 

## Installation

Install foundryup:  [Foundry Book](https://book.getfoundry.sh/getting-started/installation.html)
```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
```


Install dependencies：

```bash
  forge install dapphub/ds-test
  forge install OpenZeppelin/openzeppelin-contracts@v4.5.0
```


## Contract Deployment


deploy to eth rinkeby:
```bash
  forge create --rpc-url https://rinkeby.infura.io/v3/${YOUR_API_CODE} \
    --constructor-args "synthetic NFT" "SNFT" \
    --private-key ${YOUR_PRIVATE_KEY} \
    src/SyntheticNFT.sol:SyntheticNFT
  
```
deploy to BSC testnet:
```bash
  forge create --rpc-url  https://data-seed-prebsc-1-s1.binance.org:8545 \
    --constructor-args "synthetic NFT" "SNFT" \
    --private-key ${YOUR_PRIVATE_KEY} \
    src/SyntheticNFT.sol:SyntheticNFT
  
```

## Usage/Examples


```javascript

  uint newTokenId = _syntheticNFT.mint{value: _price}(to, contractAddr, tokenId);

  _syntheticNFT.refund(newTokenId);

```

you can get more help from test case code.
## Running Tests

To run tests, run the following command

```bash
  forge test
```


## Learn More
 - When mint, you need to inject at least 0.1 ether as asset of NFT.
 - When tranfer NFT, 5% of leftover ether asset will be charged as commission.
 - When refund/burn NFT, 10% of leftover ether asset will be charged as commission.
## Contributing

Contributions are always welcome!




## License

SyntheticNFT is released under the [MIT](https://choosealicense.com/licenses/mit/)

