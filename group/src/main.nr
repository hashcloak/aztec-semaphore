use dep::aztec::macros::aztec;

#[aztec]
pub contract Semaphore {
    use aztec::macros::functions::{external, initializer, internal};
    use aztec::{macros::storage::{self, storage}, state_vars::{Map, PublicMutable}};
    use aztec::protocol_types::address::AztecAddress;
    use binary_merkle_root::binary_merkle_root;
    use lean_imt::LeanIMT;
    use poseidon::poseidon2::Poseidon2;
    use callback_interface::CallbackInterface;

    global MAX_DEPTH: u32 = 10;

    #[storage]
    struct Storage<Context> {
        // groupID -> MerkleTree contract address
        merkle_trees: Map<Field, PublicMutable<AztecAddress, Context>, Context>,
        // groupID -> admin address
        admins: Map<Field, PublicMutable<AztecAddress, Context>, Context>,

        // Groups mapping
        // in semaphore we have mapping(uint256 => Group) public groups where Group has the below components
        group_merkle_tree_duration: Map<Field, PublicMutable<Field, Context>, Context>,
        group_merkle_tree_creation_date: Map<Field, Map<Field, PublicMutable<Field, Context>, Context>, Context>,
        group_nullifiers: Map<Field, Map<Field, PublicMutable<bool, Context>, Context>, Context>,

        group_counter: PublicMutable<Field, Context>,
    }

    // Initializing the contract with an admin and a tree contract address
    #[initializer]
    #[external("public")]
    fn initialize(admin: AztecAddress, group_id: Field, tree_address: AztecAddress) {
        let admin_storage = storage.admins;
        admin_storage.at(group_id).write(admin);

        let tree_storage = storage.merkle_trees;
        tree_storage.at(group_id).write(tree_address);

    }

    #[external("public")]
    fn update_admin(new_admin: AztecAddress, group_id: Field) {

        // Only admin can update admin
        assert_eq(storage.admins.at(group_id).read(), context.msg_sender().unwrap());

        let admin_storage = storage.admins;
        admin_storage.at(group_id).write(new_admin);
    }


    #[external("public")]
    fn create_group(tree_address: AztecAddress, admin_address: AztecAddress) {
        
        let group_id_storage = storage.group_counter;
        let group_id = group_id_storage.read() + Field::from(1);
        group_id_storage.write(group_id);
        let admin_storage = storage.admins;
        admin_storage.at(group_id).write(admin_address);

        let tree_storage = storage.merkle_trees;
        tree_storage.at(group_id).write(tree_address);

        let group_merkle_tree_duration_storage = storage.group_merkle_tree_duration;
        group_merkle_tree_duration_storage.at(group_id).write(Field::from(3600)); // 1hr

    }

    #[external("public")]
    fn add_member(
        group_id: Field,
        member: Field,
        tree_address: AztecAddress,
    ) {
        // Only admin can add members
        assert_eq(storage.admins.at(group_id).read(), context.msg_sender().unwrap());

        // Call LeanIMT contract to insert the member
        LeanIMT::at(tree_address)
            .insert(member).call(&mut context);

    }

    #[external("public")]
    #[internal]
    fn validate(group_id: Field, nullifier: Field, root: Field, tree_address: AztecAddress, call_back: AztecAddress) {
        let nullifiers_map = storage.group_nullifiers;
        let res = nullifiers_map.at(group_id).at(nullifier).read();

        assert_eq(res, false);

        let root2 = LeanIMT::at(tree_address)
            .get_root().call(&mut context);
        
        assert_eq(root, root2);

        nullifiers_map.at(group_id).at(nullifier).write(true);

        // Notify the calling contract that the proof has been validated
        CallbackInterface::at(call_back)
            .callback(group_id)
            .call(&mut context);
    }

    #[contract_library_method]
    fn poseidon2_hash_2(input: [Field; 2]) -> Field {
        Poseidon2::hash(input, 2)
    }

    #[external("private")]
    fn verify_proof(
        secret_key: Field,
        passport_id: Field,
        index_bits: [u1; MAX_DEPTH], // these bits indicate the order of inputs for hashing of the merkle proof
        hash_path: [Field; MAX_DEPTH], // the Merkle Tree inclusion proof
        merkle_proof_length: u32, // the number of non-zero elements in hash_path
        hashed_scope: Field,
        candidate: Field,
        group_id: Field,
        tree_address: AztecAddress,
    ) {
        // Part 2
        // Calculates merkle root by repeatedly hashing with the elements from the merkle proof.
        // Depending on the index bit, we swap the siblings for hashing or not.
        let root = binary_merkle_root(
            poseidon2_hash_2,
            passport_id,
            merkle_proof_length,
            index_bits,
            hash_path,
        );

          // Part 3
        // Obtain the nullifier by hashing the hashed scope and secret key.
        let nullifier = poseidon2_hash_2([hashed_scope, secret_key]);

         // TODO: compare the nullifier and root to the public storage & update the nullifier map
        Semaphore::at(context.this_address())
            .validate(group_id, nullifier, root, tree_address, context.msg_sender().unwrap())
            .enqueue(&mut context);
    }

}
