// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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
    function ethToTokenTransfer(
        uint256 _minTokens,
        address _recipient
    ) external payable;
}

/**
 * @title Exchange
 * @dev UniswapV1 交易所合约 - 处理 ETH 与单一 ERC20 代币的交易
 */
contract Exchange is ERC20 {
    // @notice 与此交易所绑定的代币地址
    address public tokenAddress;

    // @notice 工厂合约地址
    address public factoryAddress;

    // /**
    //  * @dev 构造函数 - 绑定交易所与特定代币
    //  * @param _token 要绑定的 ERC20 代币地址
    //  */
    // constructor(address _token) {
    //     // 代币地址不能为零地址
    //     require(_token != address(0), "invalid token address");
    //     tokenAddress = _token;
    // }

    // /**
    //  * @notice 初始化交易所合约
    //  * @param _token 绑定的 ERC20 代币地址
    //  */
    // constructor(address _token) ERC20("Zuniswap-V1", "ZUNI-V1") {
    //     require(_token != address(0), "invalid token address");
    //     tokenAddress = _token;
    // }

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

    /**
     * @dev 向流动性池添加资金（改进版本）
     * @param _tokenAmount 用户提供的代币数量上限
     * @notice 需要同时发送 ETH 和代币，比例必须匹配当前储备比例
     */
    function addLiquidity(uint256 _tokenAmount) public payable {
        if (getReserve() == 0) {
            // 分支1：初始化流动性池 - 允许任意比例
            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), _tokenAmount);

            // 铸造 LP 代币，数量等于存入的 ETH 数量
            uint256 liquidity = address(this).balance;
            _mint(msg.sender, liquidity);
        } else {
            // 分支2：追加流动性 - 必须维持现有比例
            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = getReserve();

            // 基于用户提供的 ETH 数量计算所需的代币数量
            uint256 tokenAmount = (msg.value * tokenReserve) / ethReserve;

            // 确保用户提供了足够的代币
            require(_tokenAmount >= tokenAmount, "insufficient token amount");

            // 只转入计算得出的精确代币数量
            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), tokenAmount);

            // 按比例铸造 LP 代币
            // 使用 `totalSupply()` 获取当前 LP 代币总供应量
            uint256 liquidity = (totalSupply() * msg.value) / ethReserve;
            _mint(msg.sender, liquidity);
        }
    }

    /**
     * @dev 获取当前代币储备量
     * @return 合约中持有的代币数量
     */
    function getReserve() public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    /**
     * @dev 基于储备比例的简单定价函数
     * @param inputReserve 输入代币的储备量
     * @param outputReserve 输出代币的储备量
     * @return 返回价格比例
     */
    function getPriceSimpleImpl(
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        // 确保储备量不为零，避免除零错误
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");

        // 返回输入储备与输出储备的比例
        return inputReserve / outputReserve;
    }

    /**
     * @dev 改进的定价函数，使用1000倍放大因子提高精度
     * @param inputReserve 输入代币的储备量
     * @param outputReserve 输出代币的储备量
     * @return 返回价格比例（放大1000倍）
     */
    function getPrice(
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");

        // 使用1000倍放大因子避免精度丢失
        return (inputReserve * 1000) / outputReserve;
    }

    /**
     * @dev 基于恒定乘积公式的金额计算函数
     * @param inputAmount 用户输入的代币数量
     * @param inputReserve 输入代币的当前储备量
     * @param outputReserve 输出代币的当前储备量
     * @return 用户能够获得的输出代币数量（扣除手续费后）
     */
    function getAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) private pure returns (uint256) {
        // 确保储备量和输入金额有效
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");
        require(inputAmount > 0, "invalid input amount");

        // 计算扣除手续费后的输入金额（1% 手续费，保留 99%）
        uint256 inputAmountWithFee = inputAmount * 99;

        // 应用恒定乘积公式：Δy = (yΔx) / (x + Δx)

        // 未计算手续费
        // return (inputAmount * outputReserve) / (inputReserve + inputAmount);

        // 计算手续费
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 100) + inputAmountWithFee;
        return numerator / denominator;
    }

    /**
     * @dev 计算用ETH购买代币的数量
     * @param _ethSold 出售的ETH数量
     * @return 能够获得的代币数量
     */
    function getTokenAmount(uint256 _ethSold) public view returns (uint256) {
        require(_ethSold > 0, "ETH amount too small");

        uint256 tokenReserve = getReserve();
        uint256 ethReserve = address(this).balance;

        // 计算：用ETH买代币
        return getAmount(_ethSold, ethReserve, tokenReserve);
    }

    /**
     * @dev 计算用代币购买ETH的数量
     * @param _tokenSold 出售的代币数量
     * @return 能够获得的ETH数量
     */
    function getEthAmount(uint256 _tokenSold) public view returns (uint256) {
        require(_tokenSold > 0, "Token amount too small");

        uint256 tokenReserve = getReserve();
        uint256 ethReserve = address(this).balance;

        // 计算：用代币买ETH
        return getAmount(_tokenSold, tokenReserve, ethReserve);
    }

    /**
     * @dev 用 ETH 购买代币的交换函数
     * @param _minTokens 用户期望获得的最小代币数量（滑点保护）
     * @notice 需要发送 ETH 到此函数（payable）
     */
    // function ethToTokenSwap(uint256 _minTokens) public payable {
    //     // 获取当前代币储备量
    //     uint256 tokenReserve = getReserve();

    //     // 计算用户能获得的代币数量
    //     // 注意：需要从当前余额中减去 msg.value，因为发送的 ETH 已被加入余额
    //     uint256 tokensBought = getAmount(
    //         msg.value,
    //         address(this).balance - msg.value, // ETH 储备量（交换前）
    //         tokenReserve // Token 储备量
    //     );

    //     // 滑点保护：确保获得的代币数量不少于用户设定的最小值
    //     require(tokensBought >= _minTokens, "insufficient output amount");

    //     // 将代币转给用户
    //     IERC20(tokenAddress).transfer(msg.sender, tokensBought);
    // }

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
            _tokensSold, // 输入的代币数量
            tokenReserve, // Token 储备量
            address(this).balance // ETH 储备量
        );

        // 滑点保护：确保获得的 ETH 数量不少于用户设定的最小值
        require(ethBought >= _minEth, "insufficient output amount");

        // 从用户账户转入代币到合约
        IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _tokensSold
        );

        // 将 ETH 转给用户
        payable(msg.sender).transfer(ethBought);
    }

    /**
     * @notice 移除流动性，返还相应比例的 ETH 和代币
     * @param _amount 要销毁的 LP 代币数量
     * @return ethAmount 返还的 ETH 数量
     * @return tokenAmount 返还的代币数量
     * @dev 根据 LP 代币在总供应量中的比例计算返还资产
     */
    function removeLiquidity(
        uint256 _amount
    ) public returns (uint256, uint256) {
        // 验证输入参数的有效性
        require(_amount > 0, "invalid amount");

        // 计算用户应得的 ETH 数量
        // 公式：用户ETH = (合约ETH余额 × 用户LP代币数量) ÷ LP代币总供应量
        uint256 ethAmount = (address(this).balance * _amount) / totalSupply();

        // 计算用户应得的代币数量
        // 公式：用户代币 = (合约代币余额 × 用户LP代币数量) ÷ LP代币总供应量
        uint256 tokenAmount = (getReserve() * _amount) / totalSupply();

        // 销毁用户的 LP 代币
        _burn(msg.sender, _amount);

        // 向用户转账 ETH
        payable(msg.sender).transfer(ethAmount);

        // 向用户转账代币
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);

        return (ethAmount, tokenAmount);
    }

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
        address exchangeAddress = IFactory(factoryAddress).getExchange(
            _tokenAddress
        );
        require(
            exchangeAddress != address(this) && exchangeAddress != address(0),
            "Exchange: invalid exchange address"
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
    function ethToTokenTransfer(
        uint256 _minTokens,
        address _recipient
    ) public payable {
        ethToToken(_minTokens, _recipient);
    }
}
