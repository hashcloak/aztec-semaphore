use dep::aztec::macros::aztec;

#[aztec]
pub contract LeanIMT {
    use aztec::macros::functions::external;
    use aztec::{macros::storage::{self, storage}, state_vars::{Map, PublicMutable}};

    #[storage]
    struct Storage<Context> {
        size: PublicMutable<Field, Context>,
        depth: PublicMutable<Field, Context>,
        sideNodes: Map<Field, PublicMutable<Field, Context>, Context>,
        leaves: Map<Field, PublicMutable<Field, Context>, Context>,
    }

    #[external("public")]
    fn insert(leaf: Field) {
        // TODO howto do this check https://github.com/zk-kit/zk-kit.solidity/blob/main/packages/lean-imt/contracts/InternalLeanIMT.sol#L41
        assert(leaf != 0, "Leaf must be non-zero");
        assert(storage.leaves.at(leaf).read() == 0, "Leaf already exists");
        // TODO finish impl
    }

}
