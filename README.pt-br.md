[![en](https://img.shields.io/badge/lang-en-red.svg)](https://github.com/izcoser/drex-oracle-contracts/)

## CoTeD smart contracts

Esse repositório contém os smart contracts desenvolvidos para o projeto CoTeD - Cotação do Tesouro Direto, submetido pela equipe [Venturus](https://github.com/venturusbr) à hackathon de tokenização de títulos públicos do tesouro. O framework usado para desenvolvimento foi o [Foundry](https://book.getfoundry.sh/). O repositório conta com testes unitários (incluindo fuzzers) e scripts de deploy.

O contrato `PriceAggregator.sol` permite que um grupo permissionado de oráculos submeta preços e taxas de tokens representando títulos do tesouro pela função `reportPrices`. A cada 30 minutos, a função `finishRounds` deve ser chamada para que os preços e taxas submetidos sejam agregados em uma média e uma mediana. Os oráculos que submetem preços mais próximos das médias ganham mais pontos (`score`).

Os dados salvos no contrato podem então ser consumidos por frontends para exibição simples e também por smart contracts que desejam construir lógica de negócios customizada baseada em preços e taxas de títulos públicos. Aplicações que são possíveis com o consumo desses dados incluem mercados de empréstimos colateralizados, mercados de troca com alavancagem, sistemas que envolvem lastros e stablecoins.

Esse contrato foi implantado na rede Sepolia no endereço [0xe10c2e06f944cb1ddb18ca478534bf55015bfe20](https://sepolia.etherscan.io/address/0xe10c2e06f944cb1ddb18ca478534bf55015bfe20). Dados não necessariamente acurados foram fornecidos para testagem do frontend.

O frontend desenvolvido encontra-se [neste](https://github.com/izcoser/coted-frontend) repositório.

## Uso

### Build

```shell
$ forge build
```

### Testes

```shell
$ forge test
```

### Licença

MIT
