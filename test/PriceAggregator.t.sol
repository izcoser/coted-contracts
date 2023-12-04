// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {PriceAggregator} from "../src/PriceAggregator.sol";
import "forge-std/console.sol";

contract PriceAggregatorTest is Test {
    PriceAggregator public priceAggregator;
    address[] public oracles;

    address constant ORACLE_1 = address(0x0);
    address constant ORACLE_2 = address(0x1);
    address constant ORACLE_3 = address(0x2);
    address constant TOKEN_1 = address(0x3);
    address constant TOKEN_2 = address(0x4);

    address constant ADMIN = address(0x5);
    address constant UNPRIVILEGED_USER = address(0x6);

    uint256 constant DECIMALS = 8;

    uint256 constant TOKEN_1_PRICE_ORACLE_1 = 1000 * 10 ** DECIMALS;
    uint256 constant TOKEN_1_PRICE_ORACLE_2 = 1200 * 10 ** DECIMALS;
    uint256 constant TOKEN_1_PRICE_ORACLE_3 = 1100 * 10 ** DECIMALS;

    uint256 constant TOKEN_2_PRICE_ORACLE_1 = 1100 * 10 ** DECIMALS;
    uint256 constant TOKEN_2_PRICE_ORACLE_2 = 1300 * 10 ** DECIMALS;
    uint256 constant TOKEN_2_PRICE_ORACLE_3 = 1100 * 10 ** DECIMALS;

    uint256 constant TOKEN_3_PRICE_ORACLE_1 = 1100 * 10 ** DECIMALS;
    uint256 constant TOKEN_3_PRICE_ORACLE_2 = 1300 * 10 ** DECIMALS;
    uint256 constant TOKEN_3_PRICE_ORACLE_3 = 1200 * 10 ** DECIMALS;

    uint256 constant TOKEN_1_APY_ORACLE_1 = 1 * 10 ** DECIMALS;
    uint256 constant TOKEN_1_APY_ORACLE_2 = 2 * 10 ** DECIMALS;
    uint256 constant TOKEN_1_APY_ORACLE_3 = 3 * 10 ** DECIMALS;

    uint256 constant TOKEN_2_APY_ORACLE_1 = 4 * 10 ** DECIMALS;
    uint256 constant TOKEN_2_APY_ORACLE_2 = 5 * 10 ** DECIMALS;
    uint256 constant TOKEN_2_APY_ORACLE_3 = 6 * 10 ** DECIMALS;

    uint256 constant TOKEN_3_APY_ORACLE_1 = 7 * 10 ** DECIMALS;
    uint256 constant TOKEN_3_APY_ORACLE_2 = 8 * 10 ** DECIMALS;
    uint256 constant TOKEN_3_APY_ORACLE_3 = 9 * 10 ** DECIMALS;

    function setUp() public {
        oracles.push(ORACLE_1);
        oracles.push(ORACLE_2);
        oracles.push(ORACLE_3);
        priceAggregator = new PriceAggregator(oracles, ADMIN);
    }

    function test_addOracle() public {
        vm.prank(ADMIN);
        priceAggregator.addOracle(UNPRIVILEGED_USER);
    }

    function testFail_addOracle() public {
        vm.prank(UNPRIVILEGED_USER);
        priceAggregator.addOracle(UNPRIVILEGED_USER);
    }

    function test_removeOracle() public {
        vm.prank(ADMIN);
        priceAggregator.removeOracle(ORACLE_1);
    }

    function testFail_removeOracle() public {
        vm.prank(UNPRIVILEGED_USER);
        priceAggregator.addOracle(ORACLE_1);
    }

    function test_reportPrice() public {
        reportPriceAs(ORACLE_1, 1, 1, TOKEN_1);
        reportPriceAs(ORACLE_2, 1, 1, TOKEN_1);
        reportPriceAs(ORACLE_3, 1, 1, TOKEN_1);
    }

    function testFail_reportPriceTwice() public {
        reportPriceAs(ORACLE_1, 1, 1, TOKEN_1);
        reportPriceAs(ORACLE_1, 1, 1, TOKEN_1);
    }

    function test_reportPriceAsAdmin() public {
        reportPriceAs(ADMIN, 1, 1, TOKEN_1);
    }

    function testFail_reportPrice() public {
        reportPriceAs(UNPRIVILEGED_USER, 1, 1, TOKEN_1);
    }

    function testFuzz_finishRounds(
        uint80[7] calldata prices,
        uint80[7] calldata apys
    ) public {
        console.log("Starting");
        address[] memory _oracles = new address[](7);
        for (uint i = 0; i < 7; i++) {
            _oracles[i] = address(uint160(i + 100)); // avoid collision with setup oracles.
        }

        uint256 sumOfPrices;
        for (uint256 i = 0; i < _oracles.length; i++) {
            vm.prank(ADMIN);
            console.log("Adding oracle %s", _oracles[i]);
            priceAggregator.addOracle(_oracles[i]);

            uint256 price = uint256(prices[i]);
            uint256 apy = uint256(apys[i]);
            sumOfPrices += price;
            reportPriceAs(_oracles[i], price, apy, TOKEN_1);
        }

        address[] memory tokens = new address[](1);
        tokens[0] = TOKEN_1;

        uint80[] memory roundIds = new uint80[](1);
        roundIds[0] = 0;

        vm.prank(ADMIN);
        priceAggregator.finishRounds(tokens, roundIds);

        PriceAggregator.FinalReport memory p_token_1 = priceAggregator.getRound(
            TOKEN_1,
            0
        );
        uint256 unitPrice_token_1 = p_token_1.avgPrice;
        assertEq(sumOfPrices / _oracles.length, unitPrice_token_1);
    }

    function test_finishRounds() public {
        reportPriceAs(
            ORACLE_1,
            TOKEN_1_PRICE_ORACLE_1,
            TOKEN_1_APY_ORACLE_1,
            TOKEN_1
        );
        reportPriceAs(
            ORACLE_2,
            TOKEN_1_PRICE_ORACLE_2,
            TOKEN_1_APY_ORACLE_2,
            TOKEN_1
        );
        reportPriceAs(
            ORACLE_3,
            TOKEN_1_PRICE_ORACLE_3,
            TOKEN_1_APY_ORACLE_3,
            TOKEN_1
        );

        reportPriceAs(
            ORACLE_1,
            TOKEN_2_PRICE_ORACLE_1,
            TOKEN_2_APY_ORACLE_1,
            TOKEN_2
        );
        reportPriceAs(
            ORACLE_2,
            TOKEN_2_PRICE_ORACLE_2,
            TOKEN_2_APY_ORACLE_2,
            TOKEN_2
        );
        reportPriceAs(
            ORACLE_3,
            TOKEN_1_PRICE_ORACLE_3,
            TOKEN_2_APY_ORACLE_3,
            TOKEN_2
        );

        uint80[] memory roundIds = new uint80[](2);
        roundIds[0] = 0;
        roundIds[1] = 0;

        address[] memory tokens = new address[](2);
        tokens[0] = TOKEN_1;
        tokens[1] = TOKEN_2;

        vm.prank(ADMIN);
        priceAggregator.finishRounds(tokens, roundIds);
        PriceAggregator.FinalReport memory p_token_1 = priceAggregator.getRound(
            TOKEN_1,
            0
        );
        uint256 unitPrice_token_1 = p_token_1.avgPrice;

        assertEq(
            unitPrice_token_1,
            (TOKEN_1_PRICE_ORACLE_1 +
                TOKEN_1_PRICE_ORACLE_2 +
                TOKEN_1_PRICE_ORACLE_3) / 3
        );

        PriceAggregator.FinalReport memory p_token_2 = priceAggregator.getRound(
            TOKEN_2,
            0
        );
        uint256 unitPrice_token_2 = p_token_2.avgPrice;

        assertEq(
            unitPrice_token_2,
            (TOKEN_2_PRICE_ORACLE_1 +
                TOKEN_2_PRICE_ORACLE_2 +
                TOKEN_2_PRICE_ORACLE_3) / 3
        );
    }

    function testFail_finishRounds() public {
        address[] memory tokens = new address[](1);
        tokens[0] = TOKEN_1;

        uint80[] memory roundIds = new uint80[](1);
        roundIds[0] = 0;

        vm.prank(UNPRIVILEGED_USER);
        priceAggregator.finishRounds(tokens, roundIds);
    }

    function reportPriceAs(
        address user,
        uint256 price,
        uint256 apy,
        address token
    ) public {
        address[] memory tokens = new address[](1);
        tokens[0] = token;

        uint256[] memory prices = new uint256[](1);
        prices[0] = price;

        uint256[] memory apys = new uint256[](1);
        apys[0] = apy;

        vm.prank(user);
        priceAggregator.reportPrices(tokens, prices, apys);
    }
}
