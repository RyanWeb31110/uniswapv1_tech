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
        tokenA = new Token("Token A", "TKNA", 1000000 * 10 ** 18);
        tokenB = new Token("Token B", "TKNB", 1000000 * 10 ** 18);
    }

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

    function testTokenToTokenSwap() public {
        // 创建两个交易所
        address exchangeAAddress = factory.createExchange(address(tokenA));
        address exchangeBAddress = factory.createExchange(address(tokenB));

        Exchange exchangeA = Exchange(exchangeAAddress);
        Exchange exchangeB = Exchange(exchangeBAddress);

        // 为两个交易所添加流动性
        vm.startPrank(liquidityProvider);
        vm.deal(liquidityProvider, 20 ether);

        tokenA.mint(liquidityProvider, 1000 * 10 ** 18);
        tokenB.mint(liquidityProvider, 1000 * 10 ** 18);

        tokenA.approve(exchangeAAddress, 1000 * 10 ** 18);
        tokenB.approve(exchangeBAddress, 1000 * 10 ** 18);

        exchangeA.addLiquidity{value: 10 ether}(1000 * 10 ** 18);
        exchangeB.addLiquidity{value: 10 ether}(1000 * 10 ** 18);
        vm.stopPrank();

        // 用户进行代币间兑换
        vm.startPrank(user);
        tokenA.mint(user, 10 * 10 ** 18);
        tokenA.approve(exchangeAAddress, 10 * 10 ** 18);

        uint256 balanceBefore = tokenB.balanceOf(user);

        exchangeA.tokenToTokenSwap(
            10 * 10 ** 18, // 出售 10 个 tokenA
            1, // 最少获得 1 个 tokenB
            address(tokenB)
        );

        uint256 balanceAfter = tokenB.balanceOf(user);

        // 验证用户获得了 tokenB
        assertTrue(balanceAfter > balanceBefore);
        vm.stopPrank();
    }
}
