# UniswapV1 技术学习项目

基于 [Jeiwan's Programming DeFi: Uniswap](https://jeiwan.net/posts/programming-defi-uniswap-1/) 系列文章的中文教学实现，使用 Foundry 框架从零构建去中心化交易所。

## 📚 系列文章

本项目对应以下原文系列，使用中文进行深度讲解：

- [Programming DeFi: Uniswap V1. Part 1](https://jeiwan.net/posts/programming-defi-uniswap-1/)
- [Programming DeFi: Uniswap V1. Part 2](https://jeiwan.net/posts/programming-defi-uniswap-2/)
- [Programming DeFi: Uniswap V1. Part 3](https://jeiwan.net/posts/programming-defi-uniswap-3/)

## 🎯 学习目标

通过动手实践理解以下核心概念：

- **自动做市商（AMM）** 的运作机制
- **恒定乘积公式** `x × y = k` 的实际应用
- **流动性池** 的管理和价格发现
- **去中心化交易所** 的底层实现原理
- **Solidity 智能合约** 开发最佳实践

## 🏗️ 项目架构

### 核心合约

```
src/
├── Token.sol      # 基于 OpenZeppelin 的 ERC20 测试代币
├── Exchange.sol   # UniswapV1 交易所核心实现
└── Factory.sol    # 工厂合约，管理多个交易对
```

### 测试框架

```
test/
├── ExchangeTest.t.sol          # Exchange 合约基础功能测试
├── ExchangeLiquidityTest.t.sol # 流动性管理专项测试
└── FactoryTest.t.sol           # Factory 合约测试套件
```

### 技术文档

```
docs/
├── UniswapV1自学系列01-Exchange 合约实现.md
├── UniswapV1自学系列02-Pricing function 定价功能.md
├── UniswapV1自学系列03-Swapping functions 交换函数.md
├── UniswapV1自学系列04-Adding Liquidity 增加流动性.md
├── UniswapV1自学系列05-LP-tokens.md
├── UniswapV1自学系列06-Fees.md
├── UniswapV1自学系列07-流动性移除与LP奖励机制.md
└── UniswapV1自学系列08-Factory.md
```

## 🚀 快速开始

### 环境要求

- [Foundry](https://getfoundry.sh/)
- Solidity 0.8.30

### 安装依赖

```bash
# 克隆项目
git clone https://github.com/RyanWeb31110/uniswapv1_tech.git
cd uniswapv1_tech

# 安装依赖
forge install
```

### 编译合约

```bash
forge build
```

### 运行测试

```bash
# 运行所有测试
forge test

# 详细输出测试过程
forge test -vvv

# 运行特定测试
forge test --match-test testAddLiquidity -v
```

### 代码格式化

```bash
forge fmt
```

## 📋 核心功能

### 1. 流动性管理

- `addLiquidity()` - 向流动性池添加 ETH 和代币
- `removeLiquidity()` - 移除流动性并获得 LP 代币奖励
- `getReserve()` - 查询代币储备量

### 2. 价格计算

- `getPrice()` - 基于储备比例计算价格
- `getTokenAmount()` - 计算 ETH 换取的代币数量（含手续费）
- `getEthAmount()` - 计算代币换取的 ETH 数量（含手续费）

### 3. 代币交换

- `ethToTokenSwap()` - ETH 换代币
- `tokenToEthSwap()` - 代币换 ETH
- `ethToTokenTransfer()` - ETH 换代币并转给指定地址
- `tokenToTokenSwap()` - 通过 ETH 中介实现代币间交换

### 4. 工厂模式

- `createExchange()` - 创建新的交易对
- `getExchange()` - 查询指定代币的交易所地址
- 支持多代币交易对管理

### 5. LP 代币系统

- 流动性提供者获得 LP 代币作为凭证
- LP 代币数量反映在池中的份额
- 移除流动性时销毁 LP 代币并返还相应资产

## 🔬 设计原理

### 恒定乘积公式

UniswapV1 使用恒定乘积公式确保流动性：

```
x × y = k
```

其中：
- `x` = ETH 储备量
- `y` = 代币储备量
- `k` = 恒定常数

### 价格机制

价格由储备比例动态决定：

```solidity
price = ethReserve / tokenReserve
```

交易规模越大，价格滑点越显著，保护池子不被完全耗尽。

### 手续费机制

每次交易收取 1% 的手续费：
- 手续费直接添加到流动性池中
- 增加了流动性提供者的被动收益
- 手续费计算公式：`amount_with_fee = amount * 99`

### LP 代币机制

流动性提供者代币（LP Token）设计：
- 初始流动性：LP 代币数量 = sqrt(eth_amount * token_amount)
- 后续添加：LP 代币数量 = min(eth_deposited / eth_reserve, token_deposited / token_reserve) * total_supply
- 移除流动性：获得的资产数量与 LP 代币占总供应量的比例成正比

## 📊 测试策略

使用 Foundry 测试框架，采用以下技术：

- `vm.startPrank(user)` - 模拟特定用户操作
- `vm.deal(user, amount)` - 为测试账户分配 ETH
- `makeAddr("user")` - 生成测试地址
- `assertEq()` - 结果断言验证

### 测试覆盖范围

- **基础功能测试**（ExchangeTest.t.sol）
  - 合约初始化和绑定
  - 价格计算准确性
  - 基本交换功能

- **流动性管理测试**（ExchangeLiquidityTest.t.sol）
  - 添加和移除流动性
  - LP 代币铸造和销毁
  - 手续费分配机制

- **工厂合约测试**（FactoryTest.t.sol）
  - 交易对创建
  - 地址映射管理
  - 重复创建防护

## 🎓 学习路径

### 基础阶段
1. **第一步**：阅读 `docs/UniswapV1自学系列01-Exchange 合约实现.md`
2. **第二步**：理解 `src/Exchange.sol` 合约结构
3. **第三步**：运行 `test/ExchangeTest.t.sol` 基础测试

### 进阶阶段
4. **第四步**：学习定价机制 - `UniswapV1自学系列02-Pricing function 定价功能.md`
5. **第五步**：掌握交换逻辑 - `UniswapV1自学系列03-Swapping functions 交换函数.md`
6. **第六步**：理解流动性管理 - `UniswapV1自学系列04-Adding Liquidity 增加流动性.md`

### 高级阶段
7. **第七步**：深入 LP 代币机制 - `UniswapV1自学系列05-LP-tokens.md`
8. **第八步**：掌握手续费分配 - `UniswapV1自学系列06-Fees.md`
9. **第九步**：学习流动性移除 - `UniswapV1自学系列07-流动性移除与LP奖励机制.md`
10. **第十步**：理解工厂模式 - `UniswapV1自学系列08-Factory.md`

## 🛠️ 开发工具

- **Foundry** - 智能合约开发框架
- **OpenZeppelin** - 安全的合约库
- **Solidity 0.8.30** - 智能合约编程语言

## 📖 相关资源

### 开发工具文档
- [Foundry 文档](https://book.getfoundry.sh/)
- [OpenZeppelin 文档](https://docs.openzeppelin.com/)

### 核心理论资料
- [Introduction to Smart Contracts](https://docs.soliditylang.org/en/latest/introduction-to-smart-contracts.html) - 智能合约、区块链和EVM的基础知识
- [Uniswap V1 Documentation](https://docs.uniswap.org/protocol/V1/introduction) - Uniswap V1 官方文档
- [Uniswap V1 Whitepaper](https://hackmd.io/@HaydenAdams/HJ9jLsfTz) - Uniswap V1 白皮书

### 理论深入
- [Let's run on-chain decentralized exchanges the way we run prediction markets](https://www.reddit.com/r/ethereum/comments/55m04x/lets_run_onchain_decentralized_exchanges_the_way/) - Vitalik Buterin 提出使用预测市场机制构建去中心化交易所的想法，启发了恒定乘积公式的应用
- [Constant Function Market Makers: DeFi's "Zero to One" Innovation](https://medium.com/bollinger-investment-group/constant-function-market-makers-defis-zero-to-one-innovation-968f77022159) - 恒定函数做市商的创新解析
- [Automated Market Making: Theory and Practice](https://web.stanford.edu/~guillean/papers/cfmm-chapter.pdf) - 自动化做市商的理论与实践

## 🎯 项目特色

- **完整的教学体系**：8 篇系列文章从基础到高级全面覆盖
- **中文深度解析**：针对中文开发者的详细技术讲解
- **实战代码演示**：每个概念都配有可运行的代码示例
- **全面的测试覆盖**：三套测试确保代码质量和功能完整性
- **渐进式学习设计**：从简单到复杂的学习路径规划

## 🔧 开发指南

### Gas 优化建议
```bash
# 生成 Gas 使用报告
forge snapshot

# 查看详细 Gas 消耗
forge test --gas-report
```

### 本地开发环境
```bash
# 启动本地测试网络
anvil

# 部署到本地网络
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --private-key <PRIVATE_KEY>
```

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request 来完善本教学项目！

### 贡献方式
- 改进代码注释和文档
- 添加更多测试用例
- 优化合约 Gas 消耗
- 提供英文版本翻译

## 📄 许可证

MIT License

---

## 项目仓库

https://github.com/RyanWeb31110/uniswapv1_tech