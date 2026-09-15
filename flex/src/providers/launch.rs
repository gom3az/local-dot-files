//! Launch provider (M2): `.desktop` scan into rows for `flex launch`.
//!
//! Row-set parity with `scripts/.config/scripts/app-cache.sh`:
//!
//! - Directories (in order): `/usr/share/applications`, then
//!   `$HOME/.local/share/applications`. Later directories win on duplicate
//!   desktop-ids (user overrides system), matching the bash assoc-array.
//! - Parsed keys: `Name` (first wins), `Exec` (first wins), `Terminal`
//!   (last wins), `NoDisplay`/`Hidden` (last wins, skip when `true`).
//!   `OnlyShowIn`/`NotShowIn`/`Icon` are parsed and ignored (shown
//!   everywhere, exactly like the bash version which never reads them).
//! - Skipped (never panic): unreadable files, missing `Name`/`Exec`,
//!   `NoDisplay`/`Hidden` set. Unreadable or field-less files log to stderr.
//! - Order: byte-lexicographic sort of the `name\texec\tterm` line, where
//!   `exec` is the field-code-stripped form — the same bytes `sort` sees in
//!   the bash cache (locale `sort` may differ for non-ASCII names; ASCII
//!   order, the reference-data case, is identical).
//!
//! `Exec` is stored **raw** (`%U`/`%F`/… preserved): the `flex-launch.sh`
//! wrapper strips field codes exactly like `launch_app_row` does. Row ids
//! are desktop-ids (`firefox.desktop`); the wrapper re-resolves the id to
//! the `.desktop` file to recover `Exec` + `Terminal`.

use std::path::{Path, PathBuf};

use crate::{Row, RowId, Tab};

/// Provider name for the `ACTION:` line.
pub const PROVIDER: &str = "launch";
/// Tab title (matches the bash `Launchers` tab).
pub const TAB_NAME: &str = "Launchers";
/// Meta text for terminal apps (matches the bash `Terminal` meta).
pub const TERMINAL_META: &str = "Terminal";

/// One parsed `.desktop` entry (raw `Exec`, `%` codes preserved).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DesktopEntry {
    /// Desktop-id (`firefox.desktop`); also the [`Row`] action id.
    pub id: String,
    /// Display name (`Name`).
    pub name: String,
    /// Raw command line (`Exec`, field codes intact for the wrapper).
    pub exec: String,
    /// Whether `Terminal` is `true` (last occurrence wins).
    pub terminal: bool,
}

/// Application directories in bash order (system, then user override).
#[must_use]
pub fn app_dirs() -> Vec<PathBuf> {
    let mut dirs = vec![PathBuf::from("/usr/share/applications")];
    if let Ok(home) = std::env::var("HOME") {
        if !home.is_empty() {
            dirs.push(PathBuf::from(home).join(".local/share/applications"));
        }
    }
    dirs
}

/// Scan `dirs` (in order) into sorted entries.
///
/// Later directories overwrite earlier ones on duplicate desktop-ids.
/// Never panics and never fails: unreadable directories/files are skipped
/// (files log to stderr); the result may be empty.
#[must_use]
pub fn scan_dirs(dirs: &[PathBuf]) -> Vec<DesktopEntry> {
    use std::collections::BTreeMap;
    let mut seen: BTreeMap<String, DesktopEntry> = BTreeMap::new();
    for dir in dirs {
        for path in desktop_files(dir) {
            let Some(id) = path
                .file_name()
                .and_then(|name| name.to_str())
                .map(str::to_string)
            else {
                continue;
            };
            match read_entry(&path) {
                Some((name, exec, terminal)) => {
                    seen.insert(
                        id.clone(),
                        DesktopEntry {
                            id,
                            name,
                            exec,
                            terminal,
                        },
                    );
                }
                None => {
                    eprintln!("flex: launch: skipping malformed entry {}", path.display());
                }
            }
        }
    }
    let mut entries: Vec<DesktopEntry> = seen.into_values().collect();
    entries.sort_by_key(sort_line);
    entries
}

/// Load rows from the real application directories (system + user).
#[must_use]
pub fn load() -> Vec<Row> {
    rows(&scan_dirs(&app_dirs()))
}

/// Map entries to [`Row`]s: id = desktop-id, label = `Name`,
/// meta = `Terminal` on terminal apps (data parity with the bash meta).
#[must_use]
pub fn rows(entries: &[DesktopEntry]) -> Vec<Row> {
    entries
        .iter()
        .map(|entry| {
            let id = RowId::new(entry.id.clone());
            if entry.terminal {
                Row::with_meta(id, entry.name.clone(), TERMINAL_META)
            } else {
                Row::new(id, entry.name.clone())
            }
        })
        .collect()
}

/// Build the `Launchers` tab: bare-rows mode, non-deletable rows.
#[must_use]
pub fn launch_tab() -> Tab {
    Tab::with_rows(TAB_NAME, load())
}

/// Build a `Launchers` tab from pre-scanned entries (tests/replays).
#[must_use]
pub fn tab_from_entries(entries: &[DesktopEntry]) -> Tab {
    Tab::with_rows(TAB_NAME, rows(entries))
}

/// Resolve a desktop-id to its raw `(Exec, terminal)` pair.
///
/// User directory wins over system (bash overwrite order); `%` codes are
/// preserved for the wrapper to strip. Returns `None` for unknown ids or
/// ids containing `/` (path traversal is never resolved).
#[must_use]
pub fn find_exec(id: &str) -> Option<(String, bool)> {
    find_exec_in(&app_dirs(), id)
}

/// [`find_exec`] over explicit directories (tests/fixtures).
#[must_use]
pub fn find_exec_in(dirs: &[PathBuf], id: &str) -> Option<(String, bool)> {
    if id.is_empty() || id.contains('/') {
        return None;
    }
    // Later dirs win in `scan_dirs`; for lookup, earlier (user) hits win,
    // so search in reverse (user first).
    for dir in dirs.iter().rev() {
        let path = dir.join(id);
        if let Some((_, exec, terminal)) = read_entry(&path) {
            return Some((exec, terminal));
        }
    }
    None
}

/// Strip `.desktop` field codes (` %U`, ` %F`, …) and surrounding spaces.
///
/// Mirrors `app-cache.sh`: `sed -E 's/ %[A-Za-z]//g; s/^ *//; s/ *$//'`.
#[must_use]
pub fn strip_field_codes(exec: &str) -> String {
    let chars: Vec<char> = exec.chars().collect();
    let mut out = String::with_capacity(exec.len());
    let mut index = 0_usize;
    while index < chars.len() {
        let is_code = chars[index] == ' '
            && chars.get(index + 1) == Some(&'%')
            && chars.get(index + 2).is_some_and(char::is_ascii_alphabetic);
        if is_code {
            index += 3;
        } else {
            out.push(chars[index]);
            index += 1;
        }
    }
    out.trim_matches(' ').to_string()
}

/// Sorted `.desktop` (`*.desktop`, filename order) files under `dir`.
fn desktop_files(dir: &Path) -> Vec<PathBuf> {
    let Ok(read_dir) = std::fs::read_dir(dir) else {
        return Vec::new();
    };
    let mut files: Vec<PathBuf> = read_dir
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| path.is_file() && path.extension().is_some_and(|ext| ext == "desktop"))
        .collect();
    files.sort();
    files
}

/// Parse one `.desktop` file into `(Name, Exec, terminal)`.
///
/// Whole-file key scan (like the bash `grep -E` prefilter, not section
/// aware): first `Name`/`Exec` win, last `Terminal`/`NoDisplay`/`Hidden`
/// win. Returns `None` (skip) on IO errors, missing `Name`/`Exec`, or
/// `NoDisplay`/`Hidden` set to `true`. Lossy UTF-8: undecodable bytes
/// become `U+FFFD` instead of failing the whole scan.
fn read_entry(path: &Path) -> Option<(String, String, bool)> {
    let bytes = std::fs::read(path).ok()?;
    let text = String::from_utf8_lossy(&bytes);
    let mut name: Option<String> = None;
    let mut exec: Option<String> = None;
    let mut terminal = false;
    let mut nodisplay = false;
    let mut hidden = false;
    for line in text.lines() {
        let line = line.strip_suffix('\r').unwrap_or(line);
        let Some((key, value)) = line.split_once('=') else {
            continue;
        };
        match key {
            "Name" => {
                if name.is_none() {
                    name = Some(value.to_string());
                }
            }
            "Exec" => {
                if exec.is_none() {
                    exec = Some(value.to_string());
                }
            }
            "Terminal" => terminal = value == "true",
            "NoDisplay" => nodisplay = value == "true",
            "Hidden" => hidden = value == "true",
            // `OnlyShowIn`/`NotShowIn`/`Icon` are parsed (recognized keys)
            // and ignored: entries show everywhere, like the bash version.
            _ => {}
        }
    }
    let name = name.filter(|value| !value.is_empty())?;
    let exec = exec.filter(|value| !value.is_empty())?;
    if nodisplay || hidden {
        return None;
    }
    Some((name, exec, terminal))
}

/// Bash-cache sort line: `name\texec-stripped\tterm`.
fn sort_line(entry: &DesktopEntry) -> String {
    let term = if entry.terminal { "true" } else { "false" };
    format!("{}\t{}\t{term}", entry.name, strip_field_codes(&entry.exec))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strip_field_codes_matches_bash_sed() {
        // `sed -E 's/ %[A-Za-z]//g; s/^ *//; s/ *$//'` on each sample.
        for (raw, stripped) in [
            ("firefox %U", "firefox"),
            ("myapp %F --foo", "myapp --foo"),
            ("run %u %i %c", "run"),
            ("no-codes --flag", "no-codes --flag"),
            ("  padded %U  ", "padded"),
            ("100% coverage", "100% coverage"),
            ("%U leading", "%U leading"),
        ] {
            assert_eq!(strip_field_codes(raw), stripped, "strip {raw:?}");
        }
    }

    #[test]
    fn terminal_flag_last_wins_and_first_name_exec_win() {
        let dir = fixture_dir("inline");
        std::fs::create_dir_all(&dir).expect("fixture dir");
        let path = dir.join("multi.desktop");
        std::fs::write(
            &path,
            "[Desktop Entry]\nName=First\nName=Second\nExec=one\nExec=two\nTerminal=false\nTerminal=true\n",
        )
        .expect("write fixture");
        let (_, exec, terminal) = read_entry(&path).expect("parses");
        assert_eq!(exec, "one");
        assert!(terminal, "last Terminal wins");
        std::fs::remove_file(&path).expect("cleanup");
    }

    /// Scratch dir for inline unit fixtures (integration fixtures live in
    /// `tests/fixtures/launch/` and are covered by `tests/launch.rs`).
    fn fixture_dir(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!("flex-launch-unit-{}-{name}", std::process::id()))
    }
}
