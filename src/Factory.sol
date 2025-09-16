// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./Exchange.sol";

/**
 * @title Factory
 * @notice UniswapV1 工厂合约，负责管理和部署交易所
 * @dev 实现交易所注册表和自动化部署功能
 */
contract Factory {
    // @notice 代币地址到交易所地址的映射
    // @dev 每个代币只能对应一个交易所
    mapping(address => address) public tokenToExchange;

    // @notice 交易所创建事件
    // @param token 代币地址
    // @param exchange 交易所地址
    event ExchangeCreated(address indexed token, address indexed exchange);

    /**
     * @notice 为指定代币创建新的交易所
     * @param _tokenAddress 要创建交易所的代币地址
     * @return exchange 新创建的交易所地址
     * @dev 每个代币只能创建一个交易所，避免流动性分散
     */
    function createExchange(
        address _tokenAddress
    ) public returns (address exchange) {
        // 验证代币地址不能为零地址
        require(_tokenAddress != address(0), "Factory: invalid token address");

        // 确保该代币尚未创建交易所
        require(
            tokenToExchange[_tokenAddress] == address(0),
            "Factory: exchange already exists"
        );

        // 部署新的交易所合约
        Exchange newExchange = new Exchange(_tokenAddress);
        exchange = address(newExchange);

        // 注册到映射表中
        tokenToExchange[_tokenAddress] = exchange;

        // 触发事件通知
        emit ExchangeCreated(_tokenAddress, exchange);

        return exchange;
    }

    /**
     * @notice 根据代币地址查询对应的交易所地址
     * @param _tokenAddress 代币地址
     * @return exchange 交易所地址，如果不存在则返回零地址
     */
    function getExchange(
        address _tokenAddress
    ) public view returns (address exchange) {
        return tokenToExchange[_tokenAddress];
    }
}
