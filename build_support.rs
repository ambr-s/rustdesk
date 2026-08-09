pub fn controller_features_conflict(controller_only: bool, host_services: bool) -> bool {
    controller_only && host_services
}
