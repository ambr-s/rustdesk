#[cfg(all(quartz, feature = "capture"))]
extern crate block;
#[macro_use]
extern crate cfg_if;
pub use hbb_common::libc;
#[cfg(all(dxgi, feature = "capture"))]
extern crate winapi;

pub use common::*;

#[cfg(all(quartz, feature = "capture"))]
pub mod quartz;

#[cfg(all(x11, feature = "capture"))]
pub mod x11;

#[cfg(all(x11, feature = "capture", feature = "wayland"))]
pub mod wayland;

#[cfg(all(dxgi, feature = "capture"))]
pub mod dxgi;

#[cfg(all(target_os = "android", feature = "capture"))]
pub mod android;

mod common;
