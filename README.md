[![pt-br](https://img.shields.io/badge/lang-pt--br-green.svg)](https://github.com/izcoser/drex-oracle-contracts/blob/main/README.pt-br.md)

## CoTeD smart contracts

This repository contains the smart contracts developed for the project CoTeD - Cotação do Tesouro Direto, submitted by the team [Venturus](https://github.com/venturusbr), which won the 2nd place prize at the [Hackathon Web3: Tokenização do Tesouro Nacional](https://web.archive.org/web/20231102034756/https://inova.serpro.gov.br/hackathon-web3-stn/). The framework used for development was [Foundry](https://book.getfoundry.sh/). The repository contains unit tests (including fuzzers) and deploy scripts.

The contract `PriceAggregator.sol` allows for a permissioned group of oracles to submit prices and rates of tokens which represent public titles of the treasury with the function `reportPrices`. Each 30 minutes, the function `finishRounds` must be called so that prices and rates may be aggregated in average and median values. The oracles that submit prices closer to the average earn more points and reputation (`score`). 

Data saved in the contract can then be consumed by frontends for simple display or other smart contracts for their custom business logic based on prices and rates of public treasury. Applications possible with this data feed include decentralized, collateralized lending markets, decentralized perpetual exchanges, stablecoins and more.

The smart contract was deployed to Sepolia at [0xe10c2e06f944cb1ddb18ca478534bf55015bfe20](https://sepolia.etherscan.io/address/0xe10c2e06f944cb1ddb18ca478534bf55015bfe20). Data (not necessarily accurate) has been provided to the contract to test the frontend. 

The frontend is found at [this](https://github.com/izcoser/drex-oracle-frontend) repository.

## Usage

### Build

```shell
$ forge build
```

### Tests

```shell
$ forge test
```

### License

MIT
