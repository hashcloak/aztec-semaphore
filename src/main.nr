use dep::aztec::{macros::aztec};

#[aztec]
pub contract Semaphore {
    use aztec::{macros::storage::{self, storage}, state_vars::{Map, PublicMutable}};
    use dep::aztec::protocol_types::traits::{Deserialize, Packable, Serialize};

    #[derive(Deserialize, Packable, Serialize, Eq)]
    struct Group {
        merkleTree: Field,
    }

    #[storage]
    struct Storage<Context> {
        next_group_id: PublicMutable<Field, Context>,
        groups: Map<Field, PublicMutable<Group, Context>, Context>,
        nullifiers: Map<Field, PublicMutable<bool, Context>, Context>,
    }

}
