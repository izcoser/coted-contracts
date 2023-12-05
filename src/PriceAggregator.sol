// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "forge-std/console.sol";

contract PriceAggregator is AccessControl {
    mapping(address token => mapping(uint80 roundId => PriceReport[] priceReports)) tokenPriceReports; // List of reports for a given token and round.
    mapping(address token => mapping(uint80 roundId => FinalReport priceReport)) tokenRoundPrice; // Aggregated price for a given token this round.
    mapping(address token => mapping(uint80 roundId => mapping(address oracle => bool reported))) oracledReported; // Check if oracle has reported.
    mapping(address token => mapping(uint80 roundId => bool finished)) roundFinished; // Check if a round has finished.
    mapping(address oracle => uint256 score) oracleScore; // Oracles have a score which determine the impact of their reports.

    address[] public oracles;

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public constant ROUND_TIME = 30 minutes;
    uint256 public constant DECIMALS = 8;
    uint256 public constant MIN_ERROR_THRESHOLD = 102 * 10 ** 6;
    uint256 public constant MAX_ERROR_THRESHOLD = 105 * 10 ** 6;
    uint256 public contractDeployment;

    error PriceAggregator__OracleAlreadyReported(
        address oracle,
        address token,
        uint80 roundId
    );

    error PriceAggregator__OracleNotRegistered(address oracle);

    error PriceAggregator__OracleAlreadyRegistered(address oracle);

    error PriceAggregator__ArrayLengthMismatch(uint256 a, uint256 b, uint256 c);

    error PriceAggregator__RoundFinishedError(address token, uint80 roundId);

    error PriceAggregator__ReportedPriceTooLarge(uint256 price); // To avoid overflows when calculating the average value.

    event PriceAggregator__PriceReported(
        address token,
        PriceReport priceReport
    );
    event PriceAggregator__RoundFinishedEvent(
        address token,
        uint80 roundId,
        FinalReport priceReport
    );

    struct PriceReport {
        uint256 apy;
        uint256 price;
        uint256 timestamp;
        address by;
    }

    struct FinalReport {
        uint256 avgApy;
        uint256 medApy;
        uint256 avgPrice;
        uint256 medPrice;
        uint256 timestamp;
        uint80 sources;
    }

    constructor(address[] memory _oracles, address _admin) {
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(ORACLE_ROLE, _admin);

        for (uint i = 0; i < _oracles.length; i++) {
            _grantRole(ORACLE_ROLE, _oracles[i]);
            oracles.push(_oracles[i]);
        }

        contractDeployment = block.timestamp;
    }

    function _setOracleScore(address oracle, uint256 score) internal {
        oracleScore[oracle] = score;
    }

    function _decrementOracleScore(address oracle) internal {
        uint256 score = oracleScore[oracle];
        if (score > 0) {
            oracleScore[oracle] -= 1;
        }
    }

    function _incrementOracleScore(address oracle) internal {
        uint256 score = oracleScore[oracle];
        if (score < 100) {
            oracleScore[oracle] += 1;
        }
    }

    function addOracle(address oracle) external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < oracles.length; i++) {
            if (oracles[i] == oracle) {
                revert PriceAggregator__OracleAlreadyRegistered(oracle);
            }
        }
        _grantRole(ORACLE_ROLE, oracle);
        oracles.push(oracle);
        oracleScore[oracle] = 100;
    }

    function removeOracle(address oracle) external onlyRole(ADMIN_ROLE) {
        uint256 index;
        bool found = false;
        for (uint256 i = 0; i < oracles.length; i++) {
            if (oracles[i] == oracle) {
                index = i;
                found = true;
                break;
            }
        }
        if (!found) {
            revert PriceAggregator__OracleNotRegistered(oracle);
        }

        _revokeRole(ORACLE_ROLE, oracle);
        oracles[index] = oracles[oracles.length - 1];
        oracles.pop();
    }

    function reportPrices(
        address[] calldata tokens,
        uint256[] calldata prices,
        uint256[] calldata apys
    ) external onlyRole(ORACLE_ROLE) {
        if (tokens.length != prices.length || tokens.length != apys.length) {
            revert PriceAggregator__ArrayLengthMismatch(
                tokens.length,
                prices.length,
                apys.length
            );
        }

        uint80 roundId = getCurrentRoundId();
        for (uint i = 0; i < tokens.length; i++) {
            address token = tokens[i];

            if (oracledReported[token][roundId][msg.sender]) {
                revert PriceAggregator__OracleAlreadyReported(
                    msg.sender,
                    token,
                    roundId
                );
            }

            if (prices[i] > type(uint128).max) {
                revert PriceAggregator__ReportedPriceTooLarge(prices[i]);
            }

            if (apys[i] > type(uint128).max) {
                revert PriceAggregator__ReportedPriceTooLarge(apys[i]);
            }

            PriceReport memory priceReport = PriceReport(
                apys[i],
                prices[i],
                block.timestamp,
                msg.sender
            );
            tokenPriceReports[token][roundId].push(priceReport);

            oracledReported[token][roundId][msg.sender] = true;
            emit PriceAggregator__PriceReported(token, priceReport);
        }
    }

    function finishRounds(
        address[] calldata tokens,
        uint80[] calldata roundIds
    ) external onlyRole(ORACLE_ROLE) {
        for (uint i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint80 roundId = roundIds[i];

            if (roundFinished[token][roundId]) {
                revert PriceAggregator__RoundFinishedError(token, roundId);
            }

            PriceReport[] storage priceReports = tokenPriceReports[token][
                roundId
            ];
            console.log(
                "Finishing round for token %s, roundId %s",
                token,
                roundId
            );
            tokenRoundPrice[token][roundId] = averagePrice(priceReports);

            roundFinished[token][roundId] = true;
            emit PriceAggregator__RoundFinishedEvent(
                token,
                roundId,
                tokenRoundPrice[token][roundId]
            );
        }
    }

    function averagePrice(
        PriceReport[] memory priceReports
    ) public returns (FinalReport memory finalPrice) {
        console.log(
            "Found %s reports, calculating average price.",
            priceReports.length
        );
        for (uint i = 0; i < priceReports.length; i++) {
            console.log("Report %s, price %s", i, priceReports[i].price);
            finalPrice.avgPrice += priceReports[i].price;
            finalPrice.avgApy += priceReports[i].apy;
        }

        uint length = priceReports.length;
        finalPrice.timestamp = block.timestamp;

        if (length > 0) {
            finalPrice.avgPrice /= length;
            finalPrice.avgApy /= length;
        }

        sort(priceReports, true); // sort by price.
        finalPrice.medPrice = length % 2 == 0
            ? (priceReports[(length / 2)].price +
                priceReports[((length / 2) + 1)].price) / 2
            : priceReports[length / 2].price;

        sort(priceReports, false); // sort by price.
        finalPrice.medApy = length % 2 == 0
            ? (priceReports[(length / 2)].apy +
                priceReports[((length / 2) + 1)].apy) / 2
            : priceReports[length / 2].apy;

        for (uint i = 0; i < length; i++) {
            uint256 reported = priceReports[i].price;
            uint256 average = finalPrice.avgPrice;
            uint256 difference = reported > average
                ? reported - average
                : average - reported;
            uint256 percentage_difference = average > 0
                ? (difference * 10 ** DECIMALS) / average
                : 0;

            if (percentage_difference > MAX_ERROR_THRESHOLD) {
                // Erro maior que 5%.
                _decrementOracleScore(priceReports[i].by);
            }
            if (percentage_difference < MIN_ERROR_THRESHOLD) {
                // Erro menor que 2%.
                _incrementOracleScore(priceReports[i].by);
            }
        }

        console.log("Average price: %s", finalPrice.avgPrice);
        console.log("Average apy: %s", finalPrice.avgApy);
        console.log("Median price: %s", finalPrice.medPrice);
        console.log("Median apy: %s", finalPrice.medPrice);
    }

    function getRound(
        address token,
        uint80 roundId
    ) external view returns (FinalReport memory priceReport) {
        return tokenRoundPrice[token][roundId];
    }

    function getLatestRound(
        address token
    ) external view returns (FinalReport memory priceReport) {
        return tokenRoundPrice[token][getCurrentRoundId()];
    }

    function getCurrentRoundId() public view returns (uint80) {
        return uint80((block.timestamp - contractDeployment) / ROUND_TIME);
    }

    function getTokenPriceReports(
        address token,
        uint80 roundId
    ) external returns (PriceReport[] memory) {
        return tokenPriceReports[token][roundId];
    }

    function getOracleScore(address oracle) public returns (uint256) {
        return oracleScore[oracle];
    }

    function getOracles()
        external
        returns (address[] memory, uint256[] memory)
    {
        uint256[] memory scores = new uint256[](oracles.length);
        address[] memory _oracles = oracles;
        for (uint256 i = 0; i < oracles.length; i++) {
            scores[i] = getOracleScore(oracles[i]);
        }
        return (_oracles, scores);
    }

    ///////////////////////////////////////// Sorting. ////////////////////////

    function sort(PriceReport[] memory arr, bool byPrice) public pure {
        if (arr.length > 0) quickSort(arr, 0, int256(arr.length - 1), byPrice);
    }

    function quickSort(
        PriceReport[] memory arr,
        int left,
        int right,
        bool byPrice
    ) internal pure {
        int i = left;
        int j = right;
        if (i == j) return;
        uint pivot = byPrice
            ? arr[uint(left + (right - left) / 2)].price
            : arr[uint(left + (right - left) / 2)].apy;
        while (i <= j) {
            while ((byPrice ? arr[uint(i)].price : arr[uint(i)].apy) > pivot)
                i++;
            while (pivot > (byPrice ? arr[uint(j)].price : arr[uint(j)].apy))
                j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j) quickSort(arr, left, j, byPrice);
        if (i < right) quickSort(arr, i, right, byPrice);
    }
}
