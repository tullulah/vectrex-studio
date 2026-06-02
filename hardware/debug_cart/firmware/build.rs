fn main() {
    // Tell cargo to re-run if memory layout changes
    println!("cargo:rerun-if-changed=memory.x");
    // Expose memory.x to the linker search path
    println!("cargo:rustc-link-search={}", std::env::current_dir().unwrap().display());
}
