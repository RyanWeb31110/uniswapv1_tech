// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/Exchange.sol";
import "../src/Token.sol";

/**
 * @title ExchangeLiquidityTest
 * @notice 测试流动性移除和 LP 奖励机制
 */
contract ExchangeLiquidityTest is Test {
    Exchange exchange;
    Token token;
    address liquidityProvider;
    address trader;

    function setUp() public {
        // 创建测试地址
        liquidityProvider = makeAddr("liquidityProvider");
        trader = makeAddr("trader");
        
        // 部署代币合约
        token = new Token("Test Token", "TT", 1000000 * 10**18);
        
        // 部署交易所合约
        exchange = new Exchange(address(token));
        
        // 为流动性提供者分配资产
        vm.deal(liquidityProvider, 1000 ether);
        token.transfer(liquidityProvider, 100000 * 10**18);
        
        // 为交易者分配资产
        vm.deal(trader, 100 ether);
    }

    /**
     * @notice 测试完整的流动性生命周期
     * @dev 包括添加流动性、交易、费用积累、移除流动性
     */
    function testCompleteLiquidityCycle() public {
        // 1. 流动性提供者添加初始流动性
        vm.startPrank(liquidityProvider);
        
        // 批准代币转账
        token.approve(address(exchange), 200 * 10**18);
        
        // 添加流动性：100 ETH + 200 代币
        exchange.addLiquidity{value: 100 ether}(200 * 10**18);
        
        // 验证初始状态
        assertEq(exchange.balanceOf(liquidityProvider), 100 ether); // LP 代币数量
        assertEq(address(exchange).balance, 100 ether); // 池中 ETH
        assertEq(exchange.getReserve(), 200 * 10**18); // 池中代币
        
        vm.stopPrank();

        // 2. 交易者进行代币交换
        vm.startPrank(trader);
        
        // 用 10 ETH 换取代币，期望至少获得 18 个代币
        uint256 traderTokensBefore = token.balanceOf(trader);
        exchange.ethToTokenSwap{value: 10 ether}(18 * 10**18);
        uint256 traderTokensAfter = token.balanceOf(trader);

        // 验证交易结果
        uint256 tokensReceived = traderTokensAfter - traderTokensBefore;
        console.log("Tokens received by trader:", tokensReceived);

        // 验证池状态变化
        console.log("ETH in pool after trade:", address(exchange).balance);
        console.log("Tokens in pool after trade:", exchange.getReserve());
        
        vm.stopPrank();

        // 3. 流动性提供者移除流动性
        vm.startPrank(liquidityProvider);
        
        uint256 lpTokens = exchange.balanceOf(liquidityProvider);
        uint256 lpEthBefore = liquidityProvider.balance;
        uint256 lpTokensBefore = token.balanceOf(liquidityProvider);

        // 移除全部流动性
        (uint256 ethReturned, uint256 tokensReturned) = exchange.removeLiquidity(lpTokens);

        uint256 lpEthAfter = liquidityProvider.balance;
        uint256 lpTokensAfter = token.balanceOf(liquidityProvider);

        // 验证返还金额
        assertEq(lpEthAfter - lpEthBefore, ethReturned);
        assertEq(lpTokensAfter - lpTokensBefore, tokensReturned);
        
        // 输出详细结果
        console.log("ETH returned to LP:", ethReturned);
        console.log("Tokens returned to LP:", tokensReturned);
        console.log("ETH change:", ethReturned - 100 ether);

        // 计算代币变化（可能是负数，所以使用条件判断）
        if (tokensReturned >= 200 * 10**18) {
            console.log("Token change (gain):", tokensReturned - 200 * 10**18);
        } else {
            console.log("Token change (loss):", 200 * 10**18 - tokensReturned);
        }
        
        vm.stopPrank();

        // 4. 分析收益情况
        // 流动性提供者获得了交易者支付的 ETH，但失去了相应的代币
        // 同时获得了交易费用作为补偿
        assertTrue(ethReturned > 100 ether, "Should get more ETH");
        assertTrue(tokensReturned < 200 * 10**18, "Token amount should decrease");
    }

    /**
     * @notice 测试多次交易的费用积累效果
     */
    function testMultipleTradesFeeAccumulation() public {
        // 添加初始流动性
        vm.startPrank(liquidityProvider);
        token.approve(address(exchange), 200 * 10**18);
        exchange.addLiquidity{value: 100 ether}(200 * 10**18);
        vm.stopPrank();

        // 记录初始池价值
        uint256 initialPoolValue = address(exchange).balance + exchange.getReserve() / 2;

        // 进行多次小额交易
        vm.startPrank(trader);
        for (uint i = 0; i < 5; i++) {
            exchange.ethToTokenSwap{value: 1 ether}(1 * 10**18);
        }
        vm.stopPrank();

        // 计算最终池价值
        uint256 finalPoolValue = address(exchange).balance + exchange.getReserve() / 2;
        
        // 由于交易费用的积累，池的总价值应该增加
        assertTrue(finalPoolValue > initialPoolValue, "Pool value should increase due to fee accumulation");

        console.log("Initial pool value:", initialPoolValue);
        console.log("Final pool value:", finalPoolValue);
        console.log("Fee earnings:", finalPoolValue - initialPoolValue);
    }
}