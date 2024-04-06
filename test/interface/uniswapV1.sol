// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2;
pragma experimental ABIEncoderV2;

interface IUniswapFactory {
    event NewExchange(address indexed token, address indexed exchange);

    function initializeFactory(address template) external;

    function createExchange(address token) external returns (address out);

    function getExchange(address token) external view returns (address out);

    function getToken(address exchange) external view returns (address out);

    function getTokenWithId(
        uint256 token_id
    ) external view returns (address out);

    function exchangeTemplate() external view returns (address out);

    function tokenCount() external view returns (uint256 out);
}

interface IUniswapExchange {
    event TokenPurchase(
        address indexed buyer,
        uint256 indexed eth_sold,
        uint256 indexed tokens_bought
    );
    event EthPurchase(
        address indexed buyer,
        uint256 indexed tokens_sold,
        uint256 indexed eth_bought
    );
    event AddLiquidity(
        address indexed provider,
        uint256 indexed eth_amount,
        uint256 indexed token_amount
    );
    event RemoveLiquidity(
        address indexed provider,
        uint256 indexed eth_amount,
        uint256 indexed token_amount
    );
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );

    function setup(address token_addr) external;

    function addLiquidity(
        uint256 min_liquidity,
        uint256 max_tokens,
        uint256 deadline
    ) external payable returns (uint256 out);

    function removeLiquidity(
        uint256 amount,
        uint256 min_eth,
        uint256 min_tokens,
        uint256 deadline
    ) external returns (uint256, uint256);

    function __default__() external payable;

    function ethToTokenSwapInput(
        uint256 min_tokens,
        uint256 deadline
    ) external payable returns (uint256 out);

    function ethToTokenTransferInput(
        uint256 min_tokens,
        uint256 deadline,
        address recipient
    ) external payable returns (uint256 out);

    function ethToTokenSwapOutput(
        uint256 tokens_bought,
        uint256 deadline
    ) external payable returns (uint256 out);

    function ethToTokenTransferOutput(
        uint256 tokens_bought,
        uint256 deadline,
        address recipient
    ) external payable returns (uint256 out);

    function tokenToEthSwapInput(
        uint256 tokens_sold,
        uint256 min_eth,
        uint256 deadline
    ) external returns (uint256 out);

    function tokenToEthTransferInput(
        uint256 tokens_sold,
        uint256 min_eth,
        uint256 deadline,
        address recipient
    ) external returns (uint256 out);

    function tokenToEthSwapOutput(
        uint256 eth_bought,
        uint256 max_tokens,
        uint256 deadline
    ) external returns (uint256 out);

    function tokenToEthTransferOutput(
        uint256 eth_bought,
        uint256 max_tokens,
        uint256 deadline,
        address recipient
    ) external returns (uint256 out);

    function tokenToTokenSwapInput(
        uint256 tokens_sold,
        uint256 min_tokens_bought,
        uint256 min_eth_bought,
        uint256 deadline,
        address token_addr
    ) external returns (uint256 out);

    function tokenToTokenTransferInput(
        uint256 tokens_sold,
        uint256 min_tokens_bought,
        uint256 min_eth_bought,
        uint256 deadline,
        address recipient,
        address token_addr
    ) external returns (uint256 out);

    function tokenToTokenSwapOutput(
        uint256 tokens_bought,
        uint256 max_tokens_sold,
        uint256 max_eth_sold,
        uint256 deadline,
        address token_addr
    ) external returns (uint256 out);

    function tokenToTokenTransferOutput(
        uint256 tokens_bought,
        uint256 max_tokens_sold,
        uint256 max_eth_sold,
        uint256 deadline,
        address recipient,
        address token_addr
    ) external returns (uint256 out);

    function tokenToExchangeSwapInput(
        uint256 tokens_sold,
        uint256 min_tokens_bought,
        uint256 min_eth_bought,
        uint256 deadline,
        address exchange_addr
    ) external returns (uint256 out);

    function tokenToExchangeTransferInput(
        uint256 tokens_sold,
        uint256 min_tokens_bought,
        uint256 min_eth_bought,
        uint256 deadline,
        address recipient,
        address exchange_addr
    ) external returns (uint256 out);

    function tokenToExchangeSwapOutput(
        uint256 tokens_bought,
        uint256 max_tokens_sold,
        uint256 max_eth_sold,
        uint256 deadline,
        address exchange_addr
    ) external returns (uint256 out);

    function tokenToExchangeTransferOutput(
        uint256 tokens_bought,
        uint256 max_tokens_sold,
        uint256 max_eth_sold,
        uint256 deadline,
        address recipient,
        address exchange_addr
    ) external returns (uint256 out);

    function getEthToTokenInputPrice(
        uint256 eth_sold
    ) external view returns (uint256 out);

    function getEthToTokenOutputPrice(
        uint256 tokens_bought
    ) external view returns (uint256 out);

    function getTokenToEthInputPrice(
        uint256 tokens_sold
    ) external view returns (uint256 out);

    function getTokenToEthOutputPrice(
        uint256 eth_bought
    ) external view returns (uint256 out);

    function tokenAddress() external view returns (address out);

    function factoryAddress() external view returns (address out);

    function balanceOf(address _owner) external view returns (uint256 out);

    function transfer(address _to, uint256 _value) external returns (bool out);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool out);

    function approve(
        address _spender,
        uint256 _value
    ) external returns (bool out);

    function allowance(
        address _owner,
        address _spender
    ) external view returns (uint256 out);

    function name() external view returns (bytes32 out);

    function symbol() external view returns (bytes32 out);

    function decimals() external view returns (uint256 out);

    function totalSupply() external view returns (uint256 out);
}
