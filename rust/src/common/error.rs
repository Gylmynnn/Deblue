//! Small `String`-based error helpers.
//!
//! The FRB bridge surfaces API failures as `String`, so every public API
//! returns [`ApiResult<T>`]. These helpers keep the `format!(...)` call
//! sites short and consistent.

/// Standard result for all FRB-exposed functions.
pub type ApiResult<T> = Result<T, String>;

/// `Err(format!(...))` shortcut.
pub fn fail<T>(msg: impl Into<String>) -> ApiResult<T> {
    Err(msg.into())
}

/// `Err(format!("{context}: {err}"))` shortcut for fallible calls.
pub fn fail_with<T>(context: impl AsRef<str>, err: impl std::fmt::Display) -> ApiResult<T> {
    Err(format!("{}: {err}", context.as_ref()))
}
