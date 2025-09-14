# UniswapV1 自学系列03：交换函数 (Swapping Functions)

> 本系列文章将带您从零构建一个 UniswapV1 去中心化交易所，深入理解 AMM（自动做市商）机制的核心原理。

## 1. 交换功能概述

在完成了定价功能的实现后，现在我们准备实现 UniswapV1 的核心交换功能。交换功能包括两个主要方向：
- ETH → Token：用户用 ETH 购买代币
- Token → ETH：用户用代币购买 ETH

## 2. ETH 到代币交换 (ethToTokenSwap)

### 2.1 功能实现

```solidity
/**
 * @dev 用 ETH 购买代币的交换函数
 * @param _minTokens 用户期望获得的最小代币数量（滑点保护）
 * @notice 需要发送 ETH 到此函数（payable）
 */
function ethToTokenSwap(uint256 _minTokens) public payable {
    // 获取当前代币储备量
    uint256 tokenReserve = getReserve();

    // 计算用户能获得的代币数量
    // 注意：需要从当前余额中减去 msg.value，因为发送的 ETH 已被加入余额
    uint256 tokensBought = getAmount(
        msg.value,
        address(this).balance - msg.value,  // ETH 储备量（交换前）
        tokenReserve                        // Token 储备量
    );

    // 滑点保护：确保获得的代币数量不少于用户设定的最小值
    require(tokensBought >= _minTokens, "insufficient output amount");

    // 将代币转给用户
    IERC20(tokenAddress).transfer(msg.sender, tokensBought);
}
```

### 2.2 关键设计要点

1. **余额计算技巧**：在 `payable` 函数中，`msg.value` 在函数调用时已经被加入合约余额，因此需要减去这部分来获取交换前的 ETH 储备量。

2. **滑点保护机制**：`_minTokens` 参数提供重要的安全保障，防止用户遭受不可接受的滑点损失。

## 3. 代币到 ETH 交换 (tokenToEthSwap)

### 3.1 功能实现

```solidity
/**
 * @dev 用代币购买 ETH 的交换函数
 * @param _tokensSold 用户出售的代币数量
 * @param _minEth 用户期望获得的最小 ETH 数量（滑点保护）
 * @notice 调用前需要先 approve 代币给此合约
 */
function tokenToEthSwap(uint256 _tokensSold, uint256 _minEth) public {
    // 获取当前代币储备量
    uint256 tokenReserve = getReserve();

    // 计算用户能获得的 ETH 数量
    uint256 ethBought = getAmount(
        _tokensSold,              // 输入的代币数量
        tokenReserve,             // Token 储备量
        address(this).balance     // ETH 储备量
    );

    // 滑点保护：确保获得的 ETH 数量不少于用户设定的最小值
    require(ethBought >= _minEth, "insufficient output amount");

    // 从用户账户转入代币到合约
    IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokensSold);

    // 将 ETH 转给用户
    payable(msg.sender).transfer(ethBought);
}
```

### 3.2 执行流程

1. 计算基于恒定乘积公式的 ETH 输出量
2. 验证输出量满足用户的最小期望
3. 执行代币转入和 ETH 转出操作

## 4. 滑点保护的重要性

滑点保护机制是 DeFi 协议中的关键安全特性：

- **前置运行攻击防护**：防止恶意机器人通过抢先交易操纵价格
- **用户体验保障**：确保用户交易结果符合预期
- **价格稳定性**：维持交易价格的合理性

滑点容忍度通常在前端界面中计算，用户可以设置可接受的最大滑点百分比。

## 5. 使用 Foundry 测试交换功能

### 5.1 测试环境准备

在测试文件 `ExchangeTest.t.sol` 中添加交换功能测试：

```solidity
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Exchange.sol";
import "../src/Token.sol";

contract ExchangeTest is Test {
    Exchange exchange;
    Token token;
    address user3 = makeAddr("user3");

    function setUp() public {
        token = new Token("Test Token", "TEST", 1000000 ether);
        exchange = new Exchange(address(token));

        // 为测试用户分配足够的代币和 ETH
        token.transfer(user3, 3000 ether);
        vm.deal(user3, 2000 ether);
    }
}
```

### 5.2 ETH → Token 交换测试

```solidity
function testEthToTokenSwap() public {
    vm.startPrank(user3);

    // 1. 添加初始流动性：2000代币 + 1000ETH
    token.approve(address(exchange), 2000 ether);
    exchange.addLiquidity{value: 1000 ether}(2000 ether);

    // 2. 获取用户初始余额
    uint256 userTokenBalanceBefore = token.balanceOf(user3);
    uint256 userEthBalanceBefore = user3.balance;

    // 3. 用 1 ETH 购买代币（期望获得至少 1.9 ETH 的代币）
    uint256 minTokens = 1.9 ether;
    exchange.ethToTokenSwap{value: 1 ether}(minTokens);

    // 4. 验证用户余额变化
    uint256 userTokenBalanceAfter = token.balanceOf(user3);
    uint256 userEthBalanceAfter = user3.balance;

    // 用户应该获得了代币
    assertGt(userTokenBalanceAfter, userTokenBalanceBefore);
    // 用户的 ETH 余额应该减少了至少 1 ETH（包含可能的 gas 费用）
    assertLe(userEthBalanceAfter, userEthBalanceBefore - 1 ether);

    // 5. 验证交易所储备变化
    assertEq(address(exchange).balance, 1001 ether); // 增加了 1 ETH
    assertLt(exchange.getReserve(), 2000 ether); // 代币储备减少

    vm.stopPrank();
}
```

### 5.3 Token → ETH 交换测试

```solidity
function testTokenToEthSwap() public {
    vm.startPrank(user3);

    // 1. 添加初始流动性：2000代币 + 1000ETH
    token.approve(address(exchange), 2000 ether);
    exchange.addLiquidity{value: 1000 ether}(2000 ether);

    // 2. 获取用户初始余额
    uint256 userTokenBalanceBefore = token.balanceOf(user3);
    uint256 userEthBalanceBefore = user3.balance;

    // 3. 用 2 个代币购买 ETH（期望获得至少 0.9 ETH）
    uint256 tokensSold = 2 ether;
    uint256 minEth = 0.9 ether;

    // 授权交易所使用代币
    token.approve(address(exchange), tokensSold);
    exchange.tokenToEthSwap(tokensSold, minEth);

    // 4. 验证用户余额变化
    uint256 userTokenBalanceAfter = token.balanceOf(user3);
    uint256 userEthBalanceAfter = user3.balance;

    // 用户的代币余额应该减少了 2 个
    assertEq(userTokenBalanceAfter, userTokenBalanceBefore - tokensSold);
    // 用户应该获得了 ETH
    assertGt(userEthBalanceAfter, userEthBalanceBefore);

    // 5. 验证交易所储备变化
    assertLt(address(exchange).balance, 1000 ether); // ETH 储备减少
    assertGt(exchange.getReserve(), 2000 ether); // 代币储备增加了 2 个

    vm.stopPrank();
}
```

### 5.4 滑点保护测试

```solidity
function testSlippageProtection() public {
    vm.startPrank(user);

    // 添加初始流动性
    token.approve(address(exchange), 2000 ether);
    exchange.addLiquidity{value: 1000 ether}(2000 ether);

    // 测试 ETH -> Token 滑点保护
    // 用 1 ETH 购买代币，但设置过高的最小期望值
    vm.expectRevert("insufficient output amount");
    exchange.ethToTokenSwap{value: 1 ether}(2.1 ether); // 期望超过2.1个代币（不可能）

    // 测试 Token -> ETH 滑点保护
    // 用 2 个代币购买 ETH，但设置过高的最小期望值
    token.approve(address(exchange), 2 ether);
    vm.expectRevert("insufficient output amount");
    exchange.tokenToEthSwap(2 ether, 1.1 ether); // 期望超过1.1个ETH（不可能）

    vm.stopPrank();
}
```



### 5.5 运行测试

使用 Foundry 命令运行测试：

```bash
# 运行所有测试
forge test

# 运行特定的交换功能测试
forge test --match-test testEthToTokenSwap -v

# 查看详细的测试输出
forge test -vvv
```



### 5.6 Foundry 测试关键技术

1. **用户身份模拟**：
   - `vm.startPrank(user)` / `vm.stopPrank()` 模拟特定用户操作
   - `makeAddr("user3")` 创建确定性的测试地址

2. **余额管理**：
   - `vm.deal(user3, amount)` 为用户分配 ETH
   - `token.transfer(user3, amount)` 为用户分配代币

3. **异常测试**：
   - `vm.expectRevert("error message")` 验证特定错误的抛出

4. **断言验证**：
   - `assertEq()` 精确匹配
   - `assertGt()` / `assertLt()` 大小比较

## 6. 小结

本章实现了 UniswapV1 的核心交换功能：

1. **双向交换支持**：ETH ↔ Token 互换
2. **滑点保护机制**：保护用户免受价格操纵
4. **完整测试覆盖**：使用 Foundry 框架进行全面测试

这些功能构成了去中心化交易所的基础交易能力，为用户提供了安全、可靠的代币交换服务。通过完善的测试验证，确保了系统的稳定性和可靠性。

---

## 📚 项目仓库

完整项目代码请访问：[https://github.com/RyanWeb31110/uniswapv1_tech](https://github.com/RyanWeb31110/uniswapv1_tech)

本系列文章是基于该项目的完整教学实现，欢迎克隆代码进行实践学习！