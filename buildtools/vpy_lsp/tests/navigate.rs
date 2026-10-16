//! Go to definition (navigate.rs) over a project on disk: locals, parameters,
//! globals, other modules, imports, struct members and assets.

use std::collections::HashMap;
use tower_lsp::lsp_types::*;
use vpy_lsp::navigate::{definition, read_with};

const MAIN: &str = r#"import zones
import util as u
from util import clamp, wrap as w

speed = 2
const LIMIT = 10

struct Ship:
    x: i16
    hp: u8 = 3

ships = Ship[4]

def main():
    DRAW_VECTOR("ship", 0, 0)

def loop():
    count = 0
    for i in range(0, 4):
        count = count + i
    zones.load(count, speed)
    u.helper()
    clamp(LIMIT)
    w(1)
    step(3)
    ships[1].hp = ships[0].x

def step(n):
    total = n + count
    return total
"#;

const ZONES: &str = "level = 0\n\ndef load(a, b):\n    level = a + b\n";
const UTIL: &str = "def helper():\n    pass\n\ndef clamp(v):\n    return v\n\ndef wrap(v):\n    return v\n";

struct Project {
    dir: std::path::PathBuf,
}

impl Project {
    fn new(name: &str) -> Self {
        let dir = std::env::temp_dir().join(format!("vpy-lsp-nav-{name}-{}", std::process::id()));
        std::fs::create_dir_all(dir.join("src")).unwrap();
        std::fs::create_dir_all(dir.join("assets/vectors")).unwrap();
        std::fs::write(dir.join("src/main.vpy"), MAIN).unwrap();
        std::fs::write(dir.join("src/zones.vpy"), ZONES).unwrap();
        std::fs::write(dir.join("src/util.vpy"), UTIL).unwrap();
        std::fs::write(dir.join("assets/vectors/ship.vec"), "{}").unwrap();
        Project { dir }
    }
    fn uri(&self, rel: &str) -> Url {
        Url::from_file_path(self.dir.join(rel).canonicalize().unwrap()).unwrap()
    }
    /// The definition of the `nth` occurrence of `needle` on the line containing `on`.
    fn go(&self, on: &str, needle: &str) -> Option<(String, u32, u32)> {
        let line = MAIN.lines().position(|l| l.contains(on)).expect("line");
        let col = MAIN.lines().nth(line).unwrap().find(needle).expect("needle") + 1;
        let open = HashMap::new();
        let read = read_with(&open);
        let uri = self.uri("src/main.vpy");
        let loc = definition(MAIN, Position { line: line as u32, character: col as u32 }, &uri, &read)?;
        let file = loc.uri.path().rsplit('/').next().unwrap().to_string();
        Some((file, loc.range.start.line + 1, loc.range.start.character))
    }
}

impl Drop for Project {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.dir);
    }
}

#[test]
fn locals_params_and_globals() {
    let p = Project::new("locals");
    // a local: its first assignment
    assert_eq!(p.go("count = count + i", "count +"), Some(("main.vpy".into(), 18, 4)));
    // a loop variable
    assert_eq!(p.go("count = count + i", " i"), Some(("main.vpy".into(), 19, 8)));
    // a global and a const
    assert_eq!(p.go("zones.load(count, speed)", "speed"), Some(("main.vpy".into(), 5, 0)));
    assert_eq!(p.go("clamp(LIMIT)", "LIMIT"), Some(("main.vpy".into(), 6, 6)));
    // a parameter, on its def line
    assert_eq!(p.go("total = n + count", "n +"), Some(("main.vpy".into(), 28, 9)));
    // a local of another function is not visible here
    assert_eq!(p.go("total = n + count", "count"), None);
    // a function of this module
    assert_eq!(p.go("step(3)", "step"), Some(("main.vpy".into(), 28, 4)));
}

#[test]
fn other_modules_and_imports() {
    let p = Project::new("modules");
    assert_eq!(p.go("zones.load(", "load"), Some(("zones.vpy".into(), 3, 4)));
    assert_eq!(p.go("zones.load(", "zones"), Some(("zones.vpy".into(), 1, 0)));
    assert_eq!(p.go("u.helper()", "helper"), Some(("util.vpy".into(), 1, 4)));
    assert_eq!(p.go("clamp(LIMIT)", "clamp"), Some(("util.vpy".into(), 4, 4)));
    assert_eq!(p.go("w(1)", "w"), Some(("util.vpy".into(), 7, 4)));
    // the import lines themselves
    assert_eq!(p.go("import zones", "zones"), Some(("zones.vpy".into(), 1, 0)));
    assert_eq!(p.go("from util import", "wrap"), Some(("util.vpy".into(), 7, 4)));
}

#[test]
fn struct_members_and_assets() {
    let p = Project::new("structs");
    assert_eq!(p.go("ships[1].hp = ships[0].x", "hp"), Some(("main.vpy".into(), 10, 4)));
    assert_eq!(p.go("ships[1].hp = ships[0].x", "ships"), Some(("main.vpy".into(), 12, 0)));
    assert_eq!(p.go("ships = Ship[4]", "Ship["), Some(("main.vpy".into(), 8, 7)));
    assert_eq!(p.go("DRAW_VECTOR(\"ship\"", "ship"), Some(("ship.vec".into(), 1, 0)));
    // a builtin has no definition
    assert_eq!(p.go("DRAW_VECTOR(\"ship\"", "DRAW_VECTOR"), None);
}
