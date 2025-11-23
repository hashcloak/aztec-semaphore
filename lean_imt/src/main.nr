use dep::aztec::macros::aztec;

#[aztec]
pub contract LeanIMT {
    use aztec::macros::functions::external;
    use aztec::{macros::storage::{self, storage}, state_vars::{Map, PublicMutable}};
    use poseidon::poseidon2::Poseidon2;
    #[storage]
    struct Storage<Context> {
        // Tracks the current number of leaves in the tree.
        size: PublicMutable<u32, Context>,
        // Represents the current depth of the tree, which can increase as new leaves are inserted.
        depth: PublicMutable<u32, Context>,
        // A mapping from each level of the tree to the node value of the last even position at that level.
        // Used for efficient inserts, updates and root calculations.
        sideNodes: Map<u32, PublicMutable<Field, Context>, Context>,
        // A mapping from leaf values to their respective indices in the tree.
        // This facilitates checks for leaf existence and retrieval of leaf positions.
        leaves: Map<Field, PublicMutable<u32, Context>, Context>,
    }

    // TODO init storage?

    #[contract_library_method]
    fn poseidon2_hash_2(input: [Field; 2]) -> Field {
        Poseidon2::hash(input, 2)
    }

    #[external("public")]
    fn insert(leaf: Field) {
        // TODO howto do this check https://github.com/zk-kit/zk-kit.solidity/blob/main/packages/lean-imt/contracts/InternalLeanIMT.sol#L41
        assert(leaf != 0, "Leaf must be non-zero");
        assert(storage.leaves.at(leaf).read() == 0, "Leaf already exists");

        let mut index = storage.size.read();
        let mut tree_depth = storage.depth.read();

        // A new insertion can increase a tree's depth by at most 1,
        // and only if the number of leaves supported by the current
        // depth is less than the number of leaves to be supported after insertion.
        // From pow_32: we assume the exponent fits into 32 bits
        if (2.pow_32(tree_depth as Field)).lt(index as Field + 1) {
            storage.depth.write(tree_depth + 1);
            tree_depth = tree_depth + 1;
        }

        let mut node = leaf;

        for level in 0..tree_depth {
            if (((index >> level) & 1) == 1) {
                node = poseidon2_hash_2([storage.sideNodes.at(level).read(), node]);
            } else {
                storage.sideNodes.at(level).write(node);
            }
        }

        index += 1;
        storage.size.write(index);

        storage.sideNodes.at(tree_depth).write(node);
        storage.leaves.at(leaf).write(index);
    }

}
