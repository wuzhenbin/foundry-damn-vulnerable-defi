// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";

contract ClimbTest is Test {
    DamnValuableToken public token;
    // UnstoppableVault vault;

    address deployer = makeAddr("deployer");
    address player = makeAddr("player");

    modifier excuteByUser(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function setUp() public excuteByUser(deployer) {}

    function testExploit() public excuteByUser(player) {}
}
