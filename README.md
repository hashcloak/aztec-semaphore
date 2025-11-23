# Semaphore in Aztec

This repo contains the semaphore implementation in aztec-noir contract.
There are 3 contracts present:
- Lean IMT: an optimized binary version of the IMT(Incremental Merkle Tree) ported from [here](https://github.com/zk-kit/zk-kit.solidity/blob/main/packages/lean-imt/contracts/LeanIMT.sol)
- Semaphore: The semaphore logic from [here](https://github.com/semaphore-protocol/semaphore).
- Callback interface: The interface to be used by contracts that use semaphore.

## Build
inside each folder run:
`aztec-nargo compile`

## Example(WIP)
The private voting contract using semaphore can be found here: https://github.com/hashcloak/humanvoting