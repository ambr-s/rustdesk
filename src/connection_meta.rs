use hbb_common::rendezvous_proto::{ControlPermissions, ControlledContext};

#[derive(Clone, Default)]
pub struct ConnectionMeta {
    pub control_permissions: Option<ControlPermissions>,
    pub controlled_context: Option<ControlledContext>,
}
