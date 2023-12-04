// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {PriceAggregator} from "../src/PriceAggregator.sol";
import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address[] memory oracles = new address[](3);
        oracles[0] = 0xd1C24B327941b189aA05b1bD542947aDf205ab4b;
        oracles[1] = 0xA391639031B2C1dC96ced90Aa3BE8B32A434f4D6;
        oracles[2] = 0x1e1AcFa6da9261D6A351c4957B12D2497BE87595;

        address admin = 0xd1C24B327941b189aA05b1bD542947aDf205ab4b;
        PriceAggregator priceAggregator = new PriceAggregator(oracles, admin);

        vm.stopBroadcast();
    }
}

contract ReportPrice is Script, Test {
    function setUp() public {}

    function run() public {
        PriceAggregator priceAggregator = PriceAggregator(
            vm.envAddress("PRICE_AGGREGATOR_ADDRESS")
        );
        uint80 currentRound = priceAggregator.getCurrentRoundId();

        address pre_token = address(0x0);
        address selic_token = address(0x1);
        address ipca_token = address(0x2);

        assertTrue(vm.exists("price_pre.txt"));
        assertTrue(vm.exists("price_selic.txt"));
        assertTrue(vm.exists("price_ipca.txt"));

        assertTrue(vm.exists("apy_pre.txt"));
        assertTrue(vm.exists("apy_selic.txt"));
        assertTrue(vm.exists("apy_ipca.txt"));

        uint256 price_pre = vm.parseUint(vm.readFile("price_pre.txt")) +
            uint(currentRound) *
            1 *
            10 ** 8;
        uint256 price_selic = vm.parseUint(vm.readFile("price_selic.txt")) +
            uint(currentRound) *
            1 *
            10 ** 8;
        uint256 price_ipca = vm.parseUint(vm.readFile("price_ipca.txt")) +
            uint(currentRound) *
            1 *
            10 ** 8;

        uint256 apy_pre = vm.parseUint(vm.readFile("apy_pre.txt")) +
            uint(currentRound) *
            1 *
            10 ** 7;
        uint256 apy_selic = vm.parseUint(vm.readFile("apy_selic.txt")) +
            uint(currentRound) *
            1 *
            10 ** 7;
        uint256 apy_ipca = vm.parseUint(vm.readFile("apy_ipca.txt")) +
            uint(currentRound) *
            1 *
            10 ** 7;

        uint256 random1 = (block.timestamp % 10) + 1;
        uint256 random2 = (block.timestamp % 6) + 1;

        address[] memory tokens = new address[](3);
        tokens[0] = pre_token;
        tokens[1] = selic_token;
        tokens[2] = ipca_token;

        uint256[] memory prices_1 = new uint256[](3);
        prices_1[0] = price_pre;
        prices_1[1] = price_selic;
        prices_1[2] = price_ipca;

        uint256[] memory prices_2 = new uint256[](3);
        prices_2[0] = (price_pre * (10 + random1)) / 10;
        prices_2[1] = (price_selic * (10 + random2)) / 10;
        prices_2[2] = (price_ipca * (10 + random1)) / 10;

        uint256[] memory prices_3 = new uint256[](3);
        prices_3[0] = (price_pre * (10 - random2)) / 10;
        prices_3[1] = (price_selic * (10 - random1)) / 10;
        prices_3[2] = (price_ipca * (10 - random2)) / 10;

        uint256[] memory apy_1 = new uint256[](3);
        apy_1[0] = apy_pre;
        apy_1[1] = apy_selic;
        apy_1[2] = apy_ipca;

        uint256[] memory apy_2 = new uint256[](3);
        apy_2[0] = (price_pre * (10 + random1)) / 10;
        apy_2[1] = (price_selic * (10 + random2)) / 10;
        apy_2[2] = (price_ipca * (10 + random1)) / 10;

        uint256[] memory apy_3 = new uint256[](3);
        apy_3[0] = (price_pre * (10 - random2)) / 10;
        apy_3[1] = (price_selic * (10 - random1)) / 10;
        apy_3[2] = (price_ipca * (10 - random2)) / 10;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        priceAggregator.reportPrices(tokens, prices_1, apy_1);
        vm.stopBroadcast();

        vm.startBroadcast(vm.envUint("PRIVATE_KEY_2"));
        priceAggregator.reportPrices(tokens, prices_2, apy_2);
        vm.stopBroadcast();

        vm.startBroadcast(vm.envUint("PRIVATE_KEY_3"));
        priceAggregator.reportPrices(tokens, prices_3, apy_3);
        vm.stopBroadcast();

        uint80[] memory rounds = new uint80[](3);

        rounds[0] = uint80(currentRound);
        rounds[1] = uint80(currentRound);
        rounds[2] = uint80(currentRound);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        priceAggregator.finishRounds(tokens, rounds);
        vm.stopBroadcast();
    }
}

contract FinishRounds is Script, Test {
    function setUp() public {}

    function run() public {
        address pre_token = address(0x0);
        address selic_token = address(0x1);
        address ipca_token = address(0x2);

        address[] memory tokens = new address[](3);
        tokens[0] = pre_token;
        tokens[1] = selic_token;
        tokens[2] = ipca_token;

        PriceAggregator priceAggregator = PriceAggregator(
            vm.envAddress("PRICE_AGGREGATOR_ADDRESS")
        );

        uint80 currentRound = priceAggregator.getCurrentRoundId();

        uint80[] memory rounds = new uint80[](3);

        rounds[0] = uint80(currentRound);
        rounds[1] = uint80(currentRound);
        rounds[2] = uint80(currentRound);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        priceAggregator.finishRounds(tokens, rounds);
        vm.stopBroadcast();
    }
}

contract CheckRound is Script {
    function setUp() public {}

    function run() public {
        address pre_token = address(0x0);
        address selic_token = address(0x1);
        address ipca_token = address(0x2);

        PriceAggregator priceAggregator = PriceAggregator(
            vm.envAddress("PRICE_AGGREGATOR_ADDRESS")
        );
        uint80 currentRound = priceAggregator.getCurrentRoundId();

        console.log("Current round: %s", currentRound);
    }
}

contract GetReports is Script {
    function setUp() public {}

    function run() public {
        address pre_token = address(0x0);
        address selic_token = address(0x1);
        address ipca_token = address(0x2);

        PriceAggregator priceAggregator = PriceAggregator(
            vm.envAddress("PRICE_AGGREGATOR_ADDRESS")
        );

        uint80 round = 75;

        PriceAggregator.PriceReport[] memory p = priceAggregator
            .getTokenPriceReports(pre_token, round);

        console.log("Price reports for round %s", round);

        for (uint i = 0; i < p.length; i++) {
            console.log("==========");
            console.log("Unit Price: %s", p[i].price);
            console.log("Timestamp: %s", p[i].timestamp);
            console.log("Reported by: %s", p[i].by);
        }
    }
}

contract GetDeploymentTime is Script {
    function setUp() public {}

    function run() public {
        PriceAggregator priceAggregator = PriceAggregator(
            vm.envAddress("PRICE_AGGREGATOR_ADDRESS")
        );
        console.log(
            "contractDeployment: %s",
            priceAggregator.contractDeployment()
        );
    }
}

contract GetLatestCompletedRound is Script {
    function run() public {
        PriceAggregator priceAggregator = PriceAggregator(
            vm.envAddress("PRICE_AGGREGATOR_ADDRESS")
        );

        address pre_token = address(0x2);
        PriceAggregator.FinalReport memory priceReport = priceAggregator
            .getLatestRound(pre_token);
        uint medPrice = priceReport.medPrice;
        uint avgPrice = priceReport.avgPrice;
        uint medApy = priceReport.medApy;
        uint avgApy = priceReport.avgApy;
        uint timestamp = priceReport.timestamp;
        uint sources = priceReport.sources;

        console.log("LatestCompletedRound: %s, %s, %s", medPrice, timestamp);
    }
}
