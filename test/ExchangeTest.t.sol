// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Exchange.sol";
import "../src/Token.sol";

contract ExchangeTest is Test {
    Exchange exchange;
    Token token;

    // 测试账户
    address user = makeAddr("user");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    function setUp() public {
        // 部署测试代币
        token = new Token("Test Token", "TEST", 1000000 ether);
        // 部署交易所
        exchange = new Exchange(address(token));

        // 给测试用户分配代币和 ETH
        token.transfer(user, 5000 ether); // 增加到5000以支持各种测试
        token.transfer(user2, 5000 ether); // 为第二个用户分配代币
        vm.deal(user, 3000 ether); // 增加到3000以支持各种测试
        vm.deal(user2, 3000 ether); // 为第二个用户分配ETH

        token.transfer(user3, 3000 ether);
        vm.deal(user3, 2000 ether);
    }

    function testAddLiquidity() public {
        vm.startPrank(user);

        // 1. 授权交易所使用用户的代币
        token.approve(address(exchange), 200 ether);

        // 2. 添加流动性：200个代币 + 100个ETH
        exchange.addLiquidity{value: 100 ether}(200 ether);

        // 3. 验证交易所余额
        assertEq(
            address(exchange).balance,
            100 ether,
            "The ETH balance is incorrect."
        );
        assertEq(
            exchange.getReserve(),
            200 ether,
            "The token balance is incorrect."
        );

        vm.stopPrank();
    }

    function testGetPriceSimpleImpl() public {
        vm.startPrank(user);

        // 1. 授权并添加流动性：2000个代币 + 1000个ETH
        token.approve(address(exchange), 2000 ether);
        exchange.addLiquidity{value: 1000 ether}(2000 ether);

        // 2. 获取当前储备量
        uint256 tokenReserve = exchange.getReserve();
        uint256 etherReserve = address(exchange).balance;

        // 3. 测试价格计算
        // ETH相对于Token的价格（应该是0.5）
        uint256 ethPerToken = exchange.getPriceSimpleImpl(
            etherReserve,
            tokenReserve
        );
        assertEq(ethPerToken, 0); // 注意：这里会失败！

        // Token相对于ETH的价格（应该是2）
        uint256 tokenPerEth = exchange.getPriceSimpleImpl(
            tokenReserve,
            etherReserve
        );
        assertEq(tokenPerEth, 2);

        vm.stopPrank();
    }

    function testGetPriceWithPrecision() public {
        vm.startPrank(user);

        // 添加流动性：2000个代币 + 1000个ETH
        token.approve(address(exchange), 2000 ether);
        exchange.addLiquidity{value: 1000 ether}(2000 ether);

        uint256 tokenReserve = exchange.getReserve();
        uint256 etherReserve = address(exchange).balance;

        // ETH相对于Token的价格：1000*1000/2000 = 500（表示0.5）
        uint256 ethPerToken = exchange.getPrice(etherReserve, tokenReserve);
        assertEq(ethPerToken, 500);

        // Token相对于ETH的价格：2000*1000/1000 = 2000（表示2.0）
        uint256 tokenPerEth = exchange.getPrice(tokenReserve, etherReserve);
        assertEq(tokenPerEth, 2000);

        vm.stopPrank();
    }

    function testGetTokenAmount() public {
        vm.startPrank(user);

        // 1. 添加初始流动性：2000代币 + 1000ETH
        token.approve(address(exchange), 2000 ether);
        exchange.addLiquidity{value: 1000 ether}(2000 ether);

        // 2. 测试用1个ETH购买代币
        uint256 tokensOut = exchange.getTokenAmount(1 ether);

        // 3. 验证结果（应约为1.998代币，略小于2代币）
        assertEq(tokensOut, 1998001998001998001);

        vm.stopPrank();
    }

    function testGetEthAmount() public {
        vm.startPrank(user);

        // 1. 添加初始流动性
        token.approve(address(exchange), 2000 ether);
        exchange.addLiquidity{value: 1000 ether}(2000 ether);

        // 2. 测试用2个代币购买ETH
        uint256 ethOut = exchange.getEthAmount(2 ether);

        // 3. 验证结果（应约为0.999ETH，略小于1ETH）
        assertEq(ethOut, 999000999000999000);

        vm.stopPrank();
    }

    function testSlippageEffect() public {
        vm.startPrank(user);

        // 初始流动性：2000代币 + 1000ETH
        token.approve(address(exchange), 2000 ether);
        exchange.addLiquidity{value: 1000 ether}(2000 ether);

        // 小额交易：1 ETH → ? 代币
        uint256 tokens1 = exchange.getTokenAmount(1 ether);
        assertEq(tokens1, 1998001998001998001); // 约1.998代币

        // 中等交易：100 ETH → ? 代币
        uint256 tokens100 = exchange.getTokenAmount(100 ether);
        assertEq(tokens100, 181818181818181818181); // 约181.8代币（滑点显著）

        // 大额交易：1000 ETH → ? 代币
        uint256 tokens1000 = exchange.getTokenAmount(1000 ether);
        console.log("tokens1000", tokens1000);
        assertEq(tokens1000, 1000 ether); // 正好1000代币（接近极限）

        vm.stopPrank();
    }

    function testReverseSlippage() public {
        vm.startPrank(user);

        // 初始流动性：2000代币 + 1000ETH
        token.approve(address(exchange), 2000 ether);
        exchange.addLiquidity{value: 1000 ether}(2000 ether);

        // 小额：2 代币 → ? ETH
        uint256 eth2 = exchange.getEthAmount(2 ether);
        assertEq(eth2, 999000999000999000); // 约0.999 ETH

        // 中等：100 代币 → ? ETH
        uint256 eth100 = exchange.getEthAmount(100 ether);
        assertEq(eth100, 47619047619047619047); // 约47.6 ETH

        // 大额：2000 代币 → ? ETH
        uint256 eth2000 = exchange.getEthAmount(2000 ether);
        console.log("eth2000", eth2000);
        assertEq(eth2000, 500 ether); // 正好500 ETH（一半储备）

        vm.stopPrank();
    }

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

    function testImprovedAddLiquidity() public {
        vm.startPrank(user);

        // 1. 第一次添加流动性（初始化池子）
        token.approve(address(exchange), 1000 ether);
        exchange.addLiquidity{value: 500 ether}(1000 ether);

        // 验证初始状态
        assertEq(address(exchange).balance, 500 ether);
        assertEq(exchange.getReserve(), 1000 ether);

        // 2. 第二次添加流动性（必须按比例）
        // 当前比例是 1000 Token : 500 ETH = 2:1
        // 如果添加 100 ETH，应该需要 200 Token
        token.approve(address(exchange), 300 ether); // 提供足够的代币授权
        exchange.addLiquidity{value: 100 ether}(300 ether);

        // 验证比例添加成功
        assertEq(address(exchange).balance, 600 ether);
        assertEq(exchange.getReserve(), 1200 ether);

        // 3. 测试代币数量不足的情况
        token.approve(address(exchange), 50 ether);
        vm.expectRevert("insufficient token amount");
        exchange.addLiquidity{value: 100 ether}(50 ether); // 只提供50个代币，但需要200个

        vm.stopPrank();
    }

    function testInitialLiquidity() public {
        vm.startPrank(user);

        // 1. 添加初始流动性：任意比例
        token.approve(address(exchange), 1000 ether);
        exchange.addLiquidity{value: 500 ether}(1000 ether);

        // 2. 验证储备状态
        assertEq(address(exchange).balance, 500 ether, "ETH reserve incorrect");
        assertEq(exchange.getReserve(), 1000 ether, "Token reserve incorrect");

        // 3. 验证初始价格设定
        // 价格比例：1000 Token : 500 ETH = 2:1
        uint256 expectedPrice = exchange.getPrice(1000 ether, 500 ether);
        assertEq(expectedPrice, 2000, "Initial price incorrect"); // 2.0 with precision

        vm.stopPrank();
    }

    function testProportionalLiquidity() public {
        // 第一个用户添加初始流动性
        vm.startPrank(user);
        token.approve(address(exchange), 1000 ether);
        exchange.addLiquidity{value: 500 ether}(1000 ether);
        vm.stopPrank();

        // 第二个用户按比例添加流动性
        vm.startPrank(user2);

        // 当前比例：1000 Token : 500 ETH = 2:1
        // 如果添加 100 ETH，应该需要 200 Token
        token.approve(address(exchange), 250 ether); // 提供足够的授权
        exchange.addLiquidity{value: 100 ether}(250 ether);

        // 验证比例添加成功
        assertEq(address(exchange).balance, 600 ether, "Total ETH incorrect");
        assertEq(exchange.getReserve(), 1200 ether, "Total tokens incorrect");

        // 验证价格比例不变
        uint256 newPrice = exchange.getPrice(1200 ether, 600 ether);
        assertEq(newPrice, 2000, "Price ratio changed"); // 仍然是 2:1

        vm.stopPrank();
    }

    function testInsufficientTokens() public {
        // 添加初始流动性
        vm.startPrank(user);
        token.approve(address(exchange), 1000 ether);
        exchange.addLiquidity{value: 500 ether}(1000 ether);
        vm.stopPrank();

        // 尝试添加流动性但代币不足
        vm.startPrank(user2);

        // 当前比例需要 200 Token，但只提供 150 Token
        token.approve(address(exchange), 150 ether);
        vm.expectRevert("insufficient token amount");
        exchange.addLiquidity{value: 100 ether}(150 ether);

        vm.stopPrank();
    }

    function testExactTokenUsage() public {
        // 添加初始流动性
        vm.startPrank(user);
        token.approve(address(exchange), 2000 ether);
        exchange.addLiquidity{value: 1000 ether}(2000 ether);
        vm.stopPrank();

        // 记录用户2的初始余额
        vm.startPrank(user2);
        uint256 initialTokenBalance = token.balanceOf(user2);

        // 提供多余的代币授权，但只应使用精确数量
        token.approve(address(exchange), 500 ether); // 授权500，但只需要200
        exchange.addLiquidity{value: 100 ether}(500 ether);

        // 验证只使用了精确的代币数量
        uint256 finalTokenBalance = token.balanceOf(user2);
        uint256 tokensUsed = initialTokenBalance - finalTokenBalance;
        assertEq(tokensUsed, 200 ether, "Should use exact token amount");

        vm.stopPrank();
    }

}
