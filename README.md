## Flashloan implementations

Here you can find an implementation of a Flashloan Lender that adheres to the [ERC-3156](https://eips.ethereum.org/EIPS/eip-3156#flash-lending-security-considerations).
Also, there are multiple implementations of Flashborrowers.

This repository was developed as part of my work towards the Certificate of Advanced Studies in Blockchain at the University of Zürich and is accompanied by a short thesis titled: "Flashloans and their applications on Ethereum-based blockchains".

The smart contracts were tested locally, at the Sepolia Network and at the University of Zürich (UZH) Proof-of-Work Ethereum-based network. As part of my work I had to mine UZH Ethereum and also deploy Uniswap at the same network. Also, I had to create situations where triangular arbitrage is possible.

## Instructions to run
### Locally
```bash
forge compile
forge test
```

### Deployment
Below I am showing an example of how to deploy and verify the FlashLender to the Base L2 Network.

```bash
❯ forge script script/DeployFlashLender.s.sol \
  --rpc-url $BASE_RPC_URL \
  --chain-id 8453 \
  --ledger \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY \
  --broadcast -vvvv
  ```

## Project Structure
```
src/
├── contracts
    └── FlashLender.sol           # Main FlashLender contract implementing ERC-3156
    ├── borrowers
        └── FlashBorrower.sol         # Basic FlashBorrower contract
        └── TriangularArbUniswapBorrower.sol  # Triangular Arbitrage borrower using UniswapV2
├── interfaces/
    └── IERC3156FlashLender.sol  # Interface for ERC-3156 FlashLender
    └── IFlashLender.sol # An enhanced interface specific to this project
    └── IERC3156FlashBorrower.sol # The interface of Flash borrowers
    └── IUniswapV2Factory.sol  # interface for Uniswap factory
    └── IUniswapV2Pair.sol     # interface for Uniswap pairs
    └── IUniswapV2Router01.sol  # basic interface for Uniswap Router
    └── IUniswapV2Router02.sol  # enhanced interface for Uniswap Router

script/
├── DeployFlashLender.s.sol   # Deployment script for FlashLender contract
├── DeployFlashBorrower.s.sol # Deployment script for FlashBorrower contract
└── DeployTriangularArbUniswapBorrower.s.sol # Deployment script for TriangularArbUniswapBorrower

test/
├── FlashLender.t.sol         # Test suite for FlashLender contract
├── FlashBorrower.t.sol       # Test suite for basic FlashBorrower
└── TriangularArbUniswapBorrower.t.sol # Test suite for TriangularArbUniswapBorrower
```

## File Descriptions

src/

- `FlashLender.sol`: The main contract implementing the ERC-3156 flash loan standard. It provides the functionality to lend assets for flash loans.
- `FlashBorrower.sol`: A basic implementation of a flash borrower that can interact with the FlashLender.
- `TriangularArbUniswapBorrower.sol`: An advanced flash borrower implementation specifically designed for triangular arbitrage operations using UniswapV2.
- `interfaces/IERC3156FlashLender.sol`: The interface defining the required functions for an ERC-3156 compliant flash lender.
- `interfaces/IFlashLender.sol`: An enhanced interface specific to this project, extending the ERC-3156 standard.
- `interfaces/IERC3156FlashBorrower.sol`: The interface defining the required functions for an ERC-3156 compliant flash borrower.
- `interfaces/IUniswapV2Factory.sol`: Interface for interacting with the Uniswap V2 factory contract.
- `interfaces/IUniswapV2Pair.sol`: Interface for interacting with Uniswap V2 pair contracts.
- `interfaces/IUniswapV2Router01.sol`: Basic interface for interacting with the Uniswap V2 router.
- `interfaces/IUniswapV2Router02.sol`: Enhanced interface for interacting with the Uniswap V2 router, including additional functions.

#### script/

- `DeployFlashLender.s.sol`: A deployment script used to deploy the FlashLender contract to the blockchain.
- `DeployFlashBorrower.s.sol`: A deployment script for deploying the basic FlashBorrower contract.
- `DeployTriangularArbUniswapBorrower.s.sol`: A deployment script for deploying the TriangularArbUniswapBorrower contract.

#### test/

- `FlashLender.t.sol`: Contains unit tests for the FlashLender contract, ensuring its functionality adheres to the ERC-3156 standard.
- `FlashBorrower.t.sol`: Test suite for the basic FlashBorrower contract, verifying its interaction with the FlashLender.
- `TriangularArbUniswapBorrower.t.sol`: Tests specific to the triangular arbitrage-focused flash borrower implementation using UniswapV2. Currently ignored but it can be tested with `script/RunTriArb.s.sol`
