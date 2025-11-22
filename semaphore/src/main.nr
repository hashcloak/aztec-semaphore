use dep::aztec::macros::aztec;

#[aztec]
pub contract Semaphore {
    use dep::aztec::protocol_types::traits::{Deserialize, Packable, Serialize, FromField};
    use aztec::macros::functions::{external, internal, initializer};
    use aztec::{macros::storage::{self, storage}, state_vars::{Map, PublicMutable}};
    use binary_merkle_root::binary_merkle_root;
    use ec::bjj::BabyJubJubParams;
    use ec::Curve;
    use ec::CurveTrait;
    use ec::ScalarField;
    use merkle_trees::merkle::MerkleTree;
    use merkle_trees::types::{Modifier, MT_Creator};
    use poseidon::poseidon2::Poseidon2;
    use std::field::bn254::assert_lt;
    use aztec::protocol_types::address::AztecAddress;

    #[derive(Deserialize, Packable, Serialize, Eq)]
    struct Group {
        merkleTree: Field,
        next_member_index: u64,
    }

    #[storage]
    struct Storage<Context> {
        next_group_id: PublicMutable<Field, Context>,
        groups: Map<Field, PublicMutable<Group, Context>, Context>,
        nullifiers: Map<Field, PublicMutable<bool, Context>, Context>,
        tally: Map<Field, Map<Field, PublicMutable<Field, Context>, Context>, Context>, // (groupID -> (candidate -> vote_count))
        admin: PublicMutable<AztecAddress, Context>,
    }

    #[initializer]
    #[external("public")]
    fn init(admin: AztecAddress) {
        let admin_storage = storage.admin;
        admin_storage.write(admin);
    }

    #[external("public")]
    fn update_admin(new_admin: AztecAddress) {
        // Only admin can update admin
        assert_eq(storage.admin.read(), context.msg_sender().unwrap());

        let admin_storage = storage.admin;
        admin_storage.write(new_admin);
    }


    #[external("public")]
    fn initialize_group(id: Field) {
        // Only admin can initialize groups
        assert_eq(storage.admin.read(), context.msg_sender().unwrap());

        // let mt = MerkleTree::<Field>::new(poseidon2_hash_2);
        let groups = storage.groups;
        let g = Group { merkleTree: Field::from(0), next_member_index: 0 };
        groups.at(id).write(g);
    }

    #[external("public")]
    fn add_member(
        group_id: Field,
        member: Field,
    ) {
        // Only admin can add members
        assert_eq(storage.admin.read(), context.msg_sender().unwrap());

        let groups = storage.groups;
        let mut group = groups.at(group_id).read();
        let mut mt = MerkleTree::<Field>::from(group.merkleTree, poseidon2_hash_2);
        mt.add(member, Field::from(group.next_member_index), [Field::from(0); 10]);
        group.merkleTree = mt.root;
        group.next_member_index += 1;
        groups.at(group_id).write(group);
    }

    global MAX_DEPTH: u32 = 10;
    // This is a 251 bit value.
    global L: Field = 2736030358979909402780800718157159386076813972158567259200215660948447373041;

    // Generator point of Baby Jubjub curve.
    // ref: https://github.com/noir-lang/noir-edwards/blob/main/src/test.nr#L6C8-L6C13
    global BASE8: [Field; 2] = [
        5299619240641551281634865583518297030282874472190772894086521144482721001553,
        16950150798460657717958625567821834550301663161624707787222815936182638968203,
    ];

    #[contract_library_method]
    fn poseidon2_hash_2(input: [Field; 2]) -> Field {
        Poseidon2::hash(input, 2)
    }

    #[external("public")]
    #[internal]
    fn _verify_and_vote(root: Field, nullifier: Field, group_id: Field, candidate: Field) {
        // check root
        let current_root = storage.groups.at(group_id).read().merkleTree;
        assert_eq(root, current_root);
        //assert nullifier does not exists
        assert_eq(storage.nullifiers.at(nullifier).read(), false);
        //store nullifier
        storage.nullifiers.at(nullifier).write(true);
        // cast the vote
        let new_tally = storage.tally.at(group_id).at(candidate).read() + 1;
        storage.tally.at(group_id).at(candidate).write(new_tally);
    }

    #[external("private")]
    #[internal]
    fn vote(
        secret_key: Field,
        index_bits: [u1; MAX_DEPTH], // these bits indicate the order of inputs for hashing of the merkle proof
        hash_path: [Field; MAX_DEPTH], // the Merkle Tree inclusion proof
        merkle_proof_length: u32, // the number of non-zero elements in hash_path
        hashed_scope: Field,
        candidate: Field,
        group_id: Field,
    ) {
        // Part 1
        // Ensure secret_key < l.
        assert_lt(secret_key, L);

        // Identity generation.
        // The public key is derived by multiplying the generator point with the secret key,
        // interpreted as a scalar.
        let generator: Curve<BabyJubJubParams> = Curve { x: BASE8[0], y: BASE8[1] };
        // ScalarField is parameterised by the number of 4-bit slices it contains.
        // Since secret key is already known to be max 251 bits, there are 63 slices.
        let secret_scalar: ScalarField<63> = ScalarField::from(secret_key);
        let pubkey = generator.mul(secret_scalar);

        // Obtain the identity commitment by hashing the public key
        let identity_commitment = poseidon2_hash_2([pubkey.x, pubkey.y]);

        // Part 2
        // Calculates merkle root by repeatedly hashing with the elements from the merkle proof.
        // Depending on the index bit, we swap the siblings for hashing or not.
        let root = binary_merkle_root(
            poseidon2_hash_2,
            identity_commitment,
            merkle_proof_length,
            index_bits,
            hash_path,
        );

        // Part 3
        // Obtain the nullifier by hashing the hashed scope and secret key.
        let nullifier = poseidon2_hash_2([hashed_scope, secret_key]);

        // TODO: compare the nullifier and root to the public storage & update the nullifier map
        Semaphore::at(context.this_address())
            ._verify_and_vote(root, nullifier, group_id, candidate)
            .enqueue(&mut context);
    }

}
