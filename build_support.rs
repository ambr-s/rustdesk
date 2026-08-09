pub fn controller_features_conflict(controller_only: bool, host_services: bool) -> bool {
    controller_only && host_services
}

pub const CONTROLLER_FEATURE_CONFLICT: &str = "controller-only cannot be combined with host-services; use --no-default-features when building the controller profile";

pub fn enforce_controller_feature_exclusivity() {
    if controller_features_conflict(
        std::env::var_os("CARGO_FEATURE_CONTROLLER_ONLY").is_some(),
        std::env::var_os("CARGO_FEATURE_HOST_SERVICES").is_some(),
    ) {
        panic!("{}", CONTROLLER_FEATURE_CONFLICT);
    }
}
