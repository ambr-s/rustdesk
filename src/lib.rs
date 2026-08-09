#[cfg(all(feature = "controller-only", feature = "host-services"))]
compile_error!(
    "controller-only cannot be combined with host-services; use --no-default-features when building the controller profile"
);

mod keyboard;
mod connection_meta;
pub use connection_meta::ConnectionMeta;
#[cfg(target_os = "linux")]
#[path = "server/dbus.rs"]
pub mod dbus;
/// cbindgen:ignore
pub mod platform;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
pub use platform::{
    clip_cursor, get_cursor, get_cursor_data, get_cursor_pos, get_focused_display,
    set_cursor_pos,
};
#[cfg(feature = "host-services")]
pub use platform::start_os_service;
#[cfg(all(
    not(target_os = "ios"),
    feature = "host-services"
))]
/// cbindgen:ignore
mod server;
#[cfg(all(
    not(target_os = "ios"),
    feature = "host-services"
))]
pub use self::server::*;
mod client;
mod lan;
#[cfg(not(any(target_os = "ios")))]
mod rendezvous_mediator;
#[cfg(not(any(target_os = "ios")))]
pub use self::rendezvous_mediator::*;
/// cbindgen:ignore
pub mod common;
#[cfg(not(any(target_os = "ios")))]
pub mod ipc;
#[cfg(not(any(
    target_os = "android",
    target_os = "ios",
    feature = "flutter"
)))]
pub mod ui;
mod version;
pub use version::*;
#[cfg(any(target_os = "android", target_os = "ios", feature = "flutter"))]
mod bridge_generated;
#[cfg(any(target_os = "android", target_os = "ios", feature = "flutter"))]
pub mod flutter;
#[cfg(any(target_os = "android", target_os = "ios", feature = "flutter"))]
pub mod flutter_ffi;
use common::*;
mod auth_2fa;
#[cfg(not(target_os = "ios"))]
mod clipboard;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
pub mod core_main;
mod custom_server;
mod lang;
#[cfg(not(any(target_os = "android", target_os = "ios")))]
mod port_forward;

#[cfg(all(feature = "flutter", feature = "plugin_framework"))]
#[cfg(not(any(target_os = "android", target_os = "ios")))]
pub mod plugin;

#[cfg(all(
    not(any(target_os = "android", target_os = "ios")),
    feature = "host-services"
))]
mod tray;

#[cfg(all(
    not(any(target_os = "android", target_os = "ios")),
    feature = "host-services"
))]
mod whiteboard;

#[cfg(not(any(target_os = "android", target_os = "ios")))]
mod updater;

mod ui_cm_interface;
mod ui_interface;
mod ui_session_interface;

mod hbbs_http;

#[cfg(any(target_os = "windows", target_os = "linux", target_os = "macos"))]
pub mod clipboard_file;

pub mod privacy_mode;

#[cfg(windows)]
pub mod virtual_display_manager;

mod kcp_stream;
