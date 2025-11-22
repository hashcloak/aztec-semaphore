use dep::aztec::{macros::aztec, protocol_types::traits::{Deserialize, Packable, Serialize}};

#[derive(Deserialize, Packable, Serialize, Eq)]
struct Group {
    // TODO what should this be
    merkleTree: Field,
}

#[aztec]
pub contract Semaphore {
    use super::Group;
    use aztec::{macros::storage::{self, storage}, state_vars::{Map, PublicMutable}};

    #[storage]
    struct Storage<Context> {
        next_group_id: PublicMutable<Field, Context>,
        // TODO this should use the Group struct instead of Field
        groups: Map<Field, PublicMutable<Field, Context>, Context>,
        nullifiers: Map<Field, PublicMutable<bool, Context>, Context>,
    }

}
