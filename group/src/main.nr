use dep::aztec::macros::aztec;

#[aztec]
pub contract Semaphore {
    use aztec::macros::functions::{external, initializer};
    use aztec::{macros::storage::{self, storage}, state_vars::{Map, PublicMutable}};
    use aztec::protocol_types::address::AztecAddress;
    use lean_imt::LeanIMT;

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

}
