//! Settings that keep a uvm2 image byte-identical from build to build.
//!
//! The m6809 path is pure Rust and deterministic by construction; the uvm2 path hands the
//! generated `.S` to the pico-sdk (CMake + GCC) and to the SDK's Rust drawing layer (cargo).
//! Two things there leaked the build's circumstances into the `.um2`:
//!
//! - the build date (`__DATE__` in the pico-sdk's standard binary info), and
//! - the builder's home directory (absolute paths in the Rust crate's panic locations).

use std::path::Path;

/// Extra UVM2_GAME_DEFS for a reproducible image.
///
/// The pico-sdk's standard binary info embeds `__DATE__` (pico_standard_binary_info,
/// `bi_program_build_date_string`), so the same game built on two different days gave two
/// different `.um2` files. With `SOURCE_DATE_EPOCH` set, GCC takes `__DATE__` from it and the
/// date stays (and is reproducible); without it, the date is left out of the image.
pub fn uvm2_reproducible_defs(source_date_epoch_set: bool) -> Vec<&'static str> {
    if source_date_epoch_set {
        Vec::new()
    } else {
        vec!["PICO_NO_BI_PROGRAM_BUILD_DATE=1"]
    }
}

/// Environment for the `cmake --build` of a uvm2 image that strips the user's home directory
/// from the Rust drawing layer (vectrex-draw). Its panic locations carry absolute paths
/// (`$HOME/.cargo/registry/...`, `$HOME/VectrexStudio/sdk/...`), so the image depended on who
/// built it. Uses CARGO_ENCODED_RUSTFLAGS (separator 0x1f) so a home with spaces survives.
/// Returns None when the user already passes rustflags through the environment: setting ours
/// would replace theirs.
pub fn uvm2_cargo_remap_env(home: Option<&Path>, user_rustflags: bool) -> Option<(&'static str, String)> {
    if user_rustflags {
        return None;
    }
    let home = home?.to_str()?.trim_end_matches(['/', '\\']);
    if home.is_empty() {
        return None;
    }
    Some(("CARGO_ENCODED_RUSTFLAGS", format!("--remap-path-prefix={}=~", home)))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn build_date_is_left_out_unless_source_date_epoch_pins_it() {
        assert_eq!(uvm2_reproducible_defs(false), vec!["PICO_NO_BI_PROGRAM_BUILD_DATE=1"]);
        assert!(uvm2_reproducible_defs(true).is_empty());
    }

    #[test]
    fn home_is_remapped_in_rust_paths() {
        let env = uvm2_cargo_remap_env(Some(Path::new("/Users/some one/")), false);
        assert_eq!(env, Some(("CARGO_ENCODED_RUSTFLAGS", "--remap-path-prefix=/Users/some one=~".to_string())));
    }

    #[test]
    fn user_rustflags_and_missing_home_are_left_alone() {
        assert_eq!(uvm2_cargo_remap_env(Some(Path::new("/home/u")), true), None);
        assert_eq!(uvm2_cargo_remap_env(None, false), None);
        assert_eq!(uvm2_cargo_remap_env(Some(Path::new("/")), false), None);
    }
}
