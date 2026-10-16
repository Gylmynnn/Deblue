//! Shared helpers for the FRB API modules (bluetooth, wifi, sound).
//!
//! Layout:
//! - [`error`] — `Result<T>` alias + small `fail` constructors.
//! - [`props`] — D-Bus `OwnedValue` property getters.
//! - [`bus`] — cached thread-local system-bus connection + `GetAll` helper.
//! - [`events`] — per-path throttling + match-rule builders for event loops.
//! - [`cmd`] — `Command` runner for CLI-backed modules (sound via `pactl`).

pub mod bus;
pub mod cmd;
pub mod error;
pub mod events;
pub mod props;
