# UniswapV1 自学系列 08：工厂合约实现

本系列文章详细介绍 UniswapV1 的核心机制和实现原理，通过从零开始构建去中心化交易所，深入理解 AMM（自动做市商）机制。本篇是系列的第八篇，将完成 UniswapV1 克隆版的最后一个重要组件：工厂合约。

## 概述

经过前面七篇文章的学习，我们已经实现了 Exchange 合约的所有核心功能，包括定价算法、代币兑换、流动性代币（LP tokens）以及手续费机制。现在我们的 UniswapV1 克隆版本已经接近完成，但还缺少一个关键组件：工厂合约（Factory Contract）。

工厂合约在 Uniswap 生态系统中扮演着至关重要的角色，它不仅充当所有交易所的注册中心，还提供了便捷的交易所部署功能。本篇文章将带您深入了解工厂合约的设计理念和实现细节。

## 工厂合约的核心价值

### 1. 交易所注册中心

工厂合约充当所有交易所的中央注册表，每个新部署的 Exchange 合约都会在工厂中进行注册。这种机制提供了以下重要功能：

- **统一发现机制**：任何交易所都可以通过查询注册表找到其他交易所
- **代币间兑换支持**：当用户需要进行代币 A → 代币 B 的兑换时，系统可以自动找到对应的交易所
- **生态系统完整性**：确保所有交易所都是经过官方认证的合约

### 2. 自动化部署服务

工厂合约提供了无需编程技能即可部署交易所的能力：

- **简化部署流程**：用户只需调用一个函数即可创建新的交易所
- **降低技术门槛**：无需处理复杂的部署脚本或开发工具
- **标准化管理**：确保所有部署的交易所都遵循统一的规范

### 3. 流动性集中化

通过限制每个代币只能有一个官方交易所，工厂合约确保：

- **避免流动性分散**：防止同一代币在多个交易所上造成流动性碎片化
- **降低滑点影响**：集中的流动性提供更好的交易价格和更低的滑点
- **提升交易体验**：用户可以享受到更优的汇率和更快的交易执行

## 工厂合约实现详解

### 基础架构设计

```solidity
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
}
```

### 核心功能实现

#### 1. 交易所创建功能

```solidity
/**
 * @notice 为指定代币创建新的交易所
 * @param _tokenAddress 要创建交易所的代币地址
 * @return exchange 新创建的交易所地址
 * @dev 每个代币只能创建一个交易所，避免流动性分散
 */
function createExchange(address _tokenAddress)
    public
    returns (address exchange)
{
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
```

**实现要点说明：**

1. **地址验证**：确保代币地址不是零地址（0x0000...），防止无效部署
2. **重复检查**：验证该代币是否已经有对应的交易所，避免重复创建
3. **合约部署**：使用 `new` 操作符部署新的 Exchange 合约
4. **注册管理**：将新交易所地址记录到映射表中
5. **事件通知**：发出事件便于前端和其他合约监听

#### 2. 交易所查询功能

```solidity
/**
 * @notice 根据代币地址查询对应的交易所地址
 * @param _tokenAddress 代币地址
 * @return exchange 交易所地址，如果不存在则返回零地址
 */
function getExchange(address _tokenAddress)
    public
    view
    returns (address exchange)
{
    return tokenToExchange[_tokenAddress];
}
```

这个函数提供了通过接口访问注册表的标准方式，其他合约可以通过此函数查找特定代币的交易所。

## Exchange 合约的工厂集成

### 构造函数更新

为了支持代币间兑换功能，我们需要将 Exchange 合约与 Factory 合约关联：

```solidity
contract Exchange is ERC20 {
    // @notice 关联的代币合约地址
    address public tokenAddress;

    // @notice 工厂合约地址
    address public factoryAddress;

    /**
     * @notice 构造函数
     * @param _token 要交易的代币地址
     * @dev 工厂地址自动设置为部署者（工厂合约）
     */
    constructor(address _token) ERC20("Zuniswap-V1", "ZUNI-V1") {
        require(_token != address(0), "Exchange: invalid token address");

        tokenAddress = _token;
        factoryAddress = msg.sender; // 工厂合约作为部署者
    }
}
```

### 工厂接口定义

为了在 Exchange 合约中调用 Factory 的功能，我们需要定义接口：

```solidity
/**
 * @title IFactory
 * @notice 工厂合约接口
 */
interface IFactory {
    /**
     * @notice 获取指定代币的交易所地址
     * @param _tokenAddress 代币地址
     * @return 交易所地址
     */
    function getExchange(address _tokenAddress) external view returns (address);
}
```

## 代币间兑换机制实现

### 兑换原理分析

代币间兑换（如 DAI → USDC）在 UniswapV1 中需要通过两步完成：

1. **第一步**：DAI → ETH（在 DAI/ETH 交易所）
2. **第二步**：ETH → USDC（在 USDC/ETH 交易所）

这种设计利用 ETH 作为中间媒介，简化了系统架构。

### 核心实现代码

```solidity
/**
 * @notice 代币间兑换功能
 * @param _tokensSold 出售的代币数量
 * @param _minTokensBought 期望获得的最少代币数量
 * @param _tokenAddress 目标代币地址
 */
function tokenToTokenSwap(
    uint256 _tokensSold,
    uint256 _minTokensBought,
    address _tokenAddress
) public {
    // 查找目标代币的交易所
    address exchangeAddress = IFactory(factoryAddress).getExchange(_tokenAddress);
    require(
        exchangeAddress != address(this) && exchangeAddress != address(0),
        "Exchange: 无效的交易所地址"
    );

    // 第一步：将用户代币兑换为 ETH
    uint256 tokenReserve = getReserve();
    uint256 ethBought = getAmount(
        _tokensSold,
        tokenReserve,
        address(this).balance
    );

    // 转移用户代币到当前交易所
    IERC20(tokenAddress).transferFrom(
        msg.sender,
        address(this),
        _tokensSold
    );

    // 第二步：在目标交易所将 ETH 兑换为目标代币
    IExchange(exchangeAddress).ethToTokenTransfer{value: ethBought}(
        _minTokensBought,
        msg.sender
    );
}
```

### Exchange 接口定义

```solidity
/**
 * @title IExchange
 * @notice 交易所合约接口
 */
interface IExchange {
    /**
     * @notice 将 ETH 兑换为代币并发送给指定接收者
     * @param _minTokens 最少获得的代币数量
     * @param _recipient 代币接收者地址
     */
    function ethToTokenTransfer(uint256 _minTokens, address _recipient)
        external
        payable;
}
```

### 优化的 ETH 到代币兑换功能

为支持代币间兑换，我们需要重构原有的 `ethToTokenSwap` 函数：

```solidity
/**
 * @notice 内部函数：ETH 兑换代币的核心逻辑
 * @param _minTokens 最少获得的代币数量
 * @param recipient 代币接收者地址
 */
function ethToToken(uint256 _minTokens, address recipient) private {
    uint256 tokenReserve = getReserve();
    uint256 tokensBought = getAmount(
        msg.value,
        address(this).balance - msg.value,
        tokenReserve
    );

    require(tokensBought >= _minTokens, "Exchange: insufficient output amount");

    IERC20(tokenAddress).transfer(recipient, tokensBought);
}

/**
 * @notice 用户调用的 ETH 兑换代币接口
 * @param _minTokens 最少获得的代币数量
 */
function ethToTokenSwap(uint256 _minTokens) public payable {
    ethToToken(_minTokens, msg.sender);
}

/**
 * @notice 支持自定义接收者的 ETH 兑换代币接口
 * @param _minTokens 最少获得的代币数量
 * @param _recipient 代币接收者地址
 */
function ethToTokenTransfer(uint256 _minTokens, address _recipient)
    public
    payable
{
    ethToToken(_minTokens, _recipient);
}
```

## 技术要点深入解析

### 1. 合约部署机制

在 Solidity 中，`new` 操作符不仅仅是创建对象实例，它实际上会在区块链上部署一个新的合约：

- **Gas 消耗**：部署新合约需要消耗大量 Gas
- **地址生成**：新合约地址由创建者地址和 nonce 值确定
- **构造函数执行**：新合约的构造函数会在部署时执行

### 2. msg.sender 的动态特性

在代币间兑换中，`msg.sender` 的值会发生变化：

- **用户调用时**：`msg.sender` 是用户地址
- **合约间调用时**：`msg.sender` 是调用合约的地址

这种特性要求我们在设计跨合约调用时特别注意接收者地址的处理。

### 3. 接口设计的重要性

使用接口而非直接合约调用的优势：

- **解耦合**：降低合约间的直接依赖
- **可升级性**：便于后续版本升级
- **标准化**：提供统一的调用规范

## 安全考虑和最佳实践

### 1. 地址验证

```solidity
// 避免零地址
require(_tokenAddress != address(0), "无效地址");

// 避免自引用
require(exchangeAddress != address(this), "不能是自己");
```

### 2. 重入攻击防护

在代币间兑换中，确保状态更新在外部调用之前完成：

```solidity
// 好的实践：先更新状态，再进行外部调用
tokenBalance -= _tokensSold;
IERC20(token).transfer(recipient, amount);
```

### 3. 滑点保护

```solidity
require(tokensBought >= _minTokens, "Exchange: insufficient output amount");
```

## 使用 Foundry 进行测试

### 基础测试设置

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/Factory.sol";
import "../src/Exchange.sol";
import "../src/Token.sol";

contract FactoryTest is Test {
    Factory factory;
    Token tokenA;
    Token tokenB;

    address user = makeAddr("user");
    address liquidityProvider = makeAddr("liquidityProvider");

    function setUp() public {
        factory = new Factory();
        tokenA = new Token("Token A", "TKNA", 1000000 * 10**18);
        tokenB = new Token("Token B", "TKNB", 1000000 * 10**18);
    }
}
```

### 工厂功能测试

```solidity
function testCreateExchange() public {
    // 创建交易所
    address exchangeAddress = factory.createExchange(address(tokenA));

    // 验证交易所地址不为零
    assertTrue(exchangeAddress != address(0));

    // 验证映射关系正确
    assertEq(factory.getExchange(address(tokenA)), exchangeAddress);
}

function testCannotCreateDuplicateExchange() public {
    // 创建第一个交易所
    factory.createExchange(address(tokenA));

    // 尝试创建重复交易所，应该失败
    vm.expectRevert("Factory: exchange already exists");
    factory.createExchange(address(tokenA));
}

function testCannotCreateExchangeWithZeroAddress() public {
    // 尝试使用零地址创建交易所，应该失败
    vm.expectRevert("Factory: invalid token address");
    factory.createExchange(address(0));
}
```

### 代币间兑换测试

```solidity
function testTokenToTokenSwap() public {
    // 创建两个交易所
    address exchangeAAddress = factory.createExchange(address(tokenA));
    address exchangeBAddress = factory.createExchange(address(tokenB));

    Exchange exchangeA = Exchange(exchangeAAddress);
    Exchange exchangeB = Exchange(exchangeBAddress);

    // 为两个交易所添加流动性
    vm.startPrank(liquidityProvider);
    vm.deal(liquidityProvider, 20 ether);

    tokenA.mint(liquidityProvider, 1000 * 10**18);
    tokenB.mint(liquidityProvider, 1000 * 10**18);

    tokenA.approve(exchangeAAddress, 1000 * 10**18);
    tokenB.approve(exchangeBAddress, 1000 * 10**18);

    exchangeA.addLiquidity{value: 10 ether}(1000 * 10**18);
    exchangeB.addLiquidity{value: 10 ether}(1000 * 10**18);
    vm.stopPrank();

    // 用户进行代币间兑换
    vm.startPrank(user);
    tokenA.mint(user, 10 * 10**18);
    tokenA.approve(exchangeAAddress, 10 * 10**18);

    uint256 balanceBefore = tokenB.balanceOf(user);

    exchangeA.tokenToTokenSwap(
        10 * 10**18,  // 出售 10 个 tokenA
        1,            // 最少获得 1 个 tokenB
        address(tokenB)
    );

    uint256 balanceAfter = tokenB.balanceOf(user);

    // 验证用户获得了 tokenB
    assertTrue(balanceAfter > balanceBefore);
    vm.stopPrank();
}
```

### 运行测试

```bash
# 运行所有测试
forge test

# 运行特定测试文件
forge test --match-contract FactoryTest

# 详细输出
forge test -vvv

# 生成 Gas 报告
forge test --gas-report
```

## 总结

通过实现工厂合约，我们完成了 UniswapV1 克隆版的所有核心功能。工厂合约作为系统的注册中心和部署工具，提供了以下关键价值：

1. **统一管理**：集中管理所有交易所，避免流动性分散
2. **简化部署**：用户无需编程技能即可创建交易所
3. **支持复杂交易**：为代币间兑换提供基础设施支持
4. **系统完整性**：确保生态系统的标准化和一致性

## 项目仓库

完整的项目代码已托管在 GitHub 上，包含所有合约实现、详细测试和部署脚本。建议读者克隆代码进行实践学习，通过动手操作加深对 UniswapV1 机制的理解。

https://github.com/RyanWeb31110/uniswapv1_tech