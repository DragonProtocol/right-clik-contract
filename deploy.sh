echo "eth rinkeby:"
forge create --rpc-url https://rinkeby.infura.io/v3/aaf906eab31742d2879c3d0a857dbeb9 --constructor-args "synthetic NFT" "SNFT" --private-key d042cab62c4a28cb3aca6dbd3edcebbb160ba4cd7a8226034824ddeaa186645e src/SyntheticNFT.sol:SyntheticNFT

echo "bsc testnet:"
forge create --rpc-url https://data-seed-prebsc-1-s1.binance.org:8545 --constructor-args "synthetic NFT" "SNFT" --private-key d042cab62c4a28cb3aca6dbd3edcebbb160ba4cd7a8226034824ddeaa186645e src/SyntheticNFT.sol:SyntheticNFT
