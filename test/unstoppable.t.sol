// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";
import {UnstoppableVault} from "../src/unstoppable/UnstoppableVault.sol";
import {ReceiverUnstoppable} from "../src/unstoppable/ReceiverUnstoppable.sol";

contract CounterTest is Test {
    DamnValuableToken public token;
    UnstoppableVault vault;
    ReceiverUnstoppable receiverContract;

    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address someUser = makeAddr("someUser");

    uint256 TOKENS_IN_VAULT = 1000000 ether;
    uint256 INITIAL_PLAYER_TOKEN_BALANCE = 10 ether;

    function setUp() public {
        vm.startPrank(deployer);

        token = new DamnValuableToken();
        vault = new UnstoppableVault(token, deployer, deployer);

        token.approve(address(vault), TOKENS_IN_VAULT);
        vault.deposit(TOKENS_IN_VAULT, deployer);

        assertEq(address(vault.asset()), address(token));
        assertEq(token.balanceOf(address(vault)), TOKENS_IN_VAULT);
        // 资金库持有的标的资产总量
        assertEq(vault.totalAssets(), TOKENS_IN_VAULT);
        // 流通中未赎回的资金库份额总数
        assertEq(vault.totalSupply(), TOKENS_IN_VAULT);
        assertEq(vault.maxFlashLoan(address(token)), TOKENS_IN_VAULT);
        assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT - 1), 0);
        assertEq(
            vault.flashFee(address(token), TOKENS_IN_VAULT),
            (TOKENS_IN_VAULT * 0.05 ether) / 1e18
        );

        token.transfer(player, INITIAL_PLAYER_TOKEN_BALANCE);
        assertEq(token.balanceOf(player), INITIAL_PLAYER_TOKEN_BALANCE);

        // Show it's possible for someUser to take out a flash loan
        receiverContract = new ReceiverUnstoppable(someUser);
        vm.expectRevert();
        receiverContract.executeFlashLoan(100 ether);

        vm.stopPrank();
    }

    function test_Increment() public {}
}
