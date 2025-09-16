// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/**
 * @title Token
 * @dev 用于测试的简单 ERC20 代币合约
 */
contract Token is ERC20 {
    /**
     * @dev 构造函数 - 创建代币并设置基本信息
     * @param name 代币名称
     * @param symbol 代币符号
     * @param initialSupply 初始供应量
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        // 将所有初始供应量铸造给合约部署者
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev 铸造新代币
     * @param to 接收代币的地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}