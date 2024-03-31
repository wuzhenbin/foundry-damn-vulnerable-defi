// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "solmate/src/utils/FixedPointMathLib.sol";

contract SimpleStorage {
    uint256 favoriteNumber;

    function store(uint256 _favoriteNumber) public virtual {
        favoriteNumber = _favoriteNumber;
    }
}

contract simpleTest is Test {
    using FixedPointMathLib for uint256;

    function setUp() public {}

    function testCalc() public view {
        uint256 a = 2 ether;
        uint256 b = 2 ether;
        console.log(a.mulWadUp(b));
        console.log((a * b) / 1e18);
    }

    function test_Increment() public {}
}
