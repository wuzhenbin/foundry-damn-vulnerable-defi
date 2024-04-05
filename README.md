```shell
forge test --match-path ./test/unstoppable.t.sol
forge test --match-path ./test/naive-receiver.t.sol
forge test --match-path ./test/truster.t.sol
forge test --match-path ./test/side-entrance.t.sol
forge test --match-path ./test/the-rewarder.t.sol
forge test --match-path ./test/selfie.t.sol
forge test --match-path ./test/compromised.t.sol

forge test --match-path ./test/sub/SimpleStorage.t.sol
forge inspect UnstoppableVault methods
forge inspect NaiveReceiverLenderPool methods

yarn install

git rm --cached lib/ -r
git rm --cached node_modules/ -r

surya describe src/the-rewarder/FlashLoanerPool.sol
surya describe src/the-rewarder/AccountingToken.sol
surya describe src/the-rewarder/RewardToken.sol
surya describe src/the-rewarder/TheRewarderPool.sol

surya graph src/the-rewarder/FlashLoanerPool.sol | dot -Tpng > graph/the-rewarder/FlashLoanerPool.png
surya graph src/the-rewarder/AccountingToken.sol | dot -Tpng > graph/the-rewarder/AccountingToken.png
surya graph src/the-rewarder/RewardToken.sol | dot -Tpng > graph/the-rewarder/RewardToken.png
surya graph src/the-rewarder/TheRewarderPool.sol | dot -Tpng > graph/the-rewarder/TheRewarderPool.png

surya graph src/Selfie/SimpleGovernance.sol | dot -Tpng > graph/Selfie/SimpleGovernance.png
surya graph src/Selfie/SelfiePool.sol | dot -Tpng > graph/Selfie/SelfiePool.png
```

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
