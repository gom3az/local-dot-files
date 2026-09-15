//! `flex launch` cutover tests (M2): provider fixtures, key-seq replays,
//! launch golden, `FLEX_TEST` determinism, and the bash-cache parity probe.
//!
//! Fixtures live in `tests/fixtures/launch/` (see `src/providers/launch.rs`
//! for the parse rules under test).

use std::path::PathBuf;

use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use ratatui::backend::TestBackend;
use ratatui::Terminal;

use flex_core::keys::{handle_key, KeyOutcome, EXIT_CANCELLED};
use flex_core::{backend, run, width, Menu, Row, RowId, Tab};
use flex_rice::providers::launch;

fn fixtures_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests")
        .join("fixtures")
        .join("launch")
}

fn fixture_entries() -> Vec<launch::DesktopEntry> {
    launch::scan_dirs(std::slice::from_ref(&fixtures_dir()))
}

fn fixture_menu() -> Menu {
    let tab = launch::tab_from_entries(&fixture_entries());
    flex_rice::menu(launch::PROVIDER, vec![tab])
}

fn press(code: KeyCode) -> KeyEvent {
    KeyEvent::new(code, KeyModifiers::NONE)
}

fn rune(c: char) -> KeyEvent {
    press(KeyCode::Char(c))
}

// --- Provider fixtures ------------------------------------------------------

#[test]
fn nodisplay_hidden_and_malformed_entries_are_skipped() {
    let entries = fixture_entries();
    let ids: Vec<&str> = entries.iter().map(|entry| entry.id.as_str()).collect();
    assert_eq!(
        ids,
        vec![
            "firefox.desktop",
            "terminal-app.desktop",
            "onlyshow-app.desktop",
            "percent-app.desktop",
        ],
        "sorted survivor set (labels: Firefox, Htop, OnlyShow, Percent App)"
    );
}

#[test]
fn action_ids_are_desktop_ids_and_terminal_rows_are_marked() {
    let tab = launch::tab_from_entries(&fixture_entries());
    assert_eq!(tab.name, launch::TAB_NAME);
    assert!(tab.bare_rows, "launcher renders bare rows");
    assert!(!tab.deletable, "launcher rows are non-deletable");
    let firefox = tab.rows.first().expect("first row");
    assert_eq!(firefox.id.as_str(), "firefox.desktop");
    assert_eq!(firefox.label, "Firefox");
    assert_eq!(firefox.meta, None);
    let htop = tab.rows.get(1).expect("second row");
    assert_eq!(htop.id.as_str(), "terminal-app.desktop");
    assert_eq!(htop.meta.as_deref(), Some(launch::TERMINAL_META));
}

#[test]
fn percent_codes_are_preserved_for_the_wrapper_to_strip() {
    let dirs = vec![fixtures_dir()];
    let (exec, terminal) = launch::find_exec_in(&dirs, "firefox.desktop").expect("firefox Exec");
    assert!(exec.contains("%U"), "raw %U preserved: {exec:?}");
    assert!(!terminal);
    let (exec, _) = launch::find_exec_in(&dirs, "percent-app.desktop").expect("percent Exec");
    assert_eq!(exec, "myapp %F --open");
    assert_eq!(launch::strip_field_codes(&exec), "myapp --open");
    assert!(launch::find_exec_in(&dirs, "missing.desktop").is_none());
    assert!(launch::find_exec_in(&dirs, "../escape.desktop").is_none());
}

#[test]
fn user_dir_overrides_system_dir_on_duplicate_ids() {
    let system = fixtures_dir().join("override-system");
    let user = fixtures_dir().join("override-user");
    std::fs::create_dir_all(&system).expect("system dir");
    std::fs::create_dir_all(&user).expect("user dir");
    std::fs::write(
        system.join("dup.desktop"),
        "[Desktop Entry]\nName=System Name\nExec=system-app\n",
    )
    .expect("system entry");
    std::fs::write(
        user.join("dup.desktop"),
        "[Desktop Entry]\nName=User Name\nExec=user-app\n",
    )
    .expect("user entry");
    let entries = launch::scan_dirs(&[system.clone(), user.clone()]);
    std::fs::remove_dir_all(&system).expect("cleanup");
    std::fs::remove_dir_all(&user).expect("cleanup");
    assert_eq!(entries.len(), 1);
    assert_eq!(entries[0].name, "User Name");
    assert_eq!(entries[0].exec, "user-app");
}

// --- Key-seq replays ----------------------------------------------------------

#[test]
fn keyseq_type_fir_enter_selects_firefox() {
    let mut menu = fixture_menu();
    let base = run::test_base();
    let outcome = run::replay_keys(
        &mut menu,
        &[rune('f'), rune('i'), rune('r'), press(KeyCode::Enter)],
        base,
    );
    assert_eq!(outcome, KeyOutcome::Select);
    let row = menu.app.focused_row().expect("focused row");
    assert_eq!(row.id.as_str(), "firefox.desktop");
    assert_eq!(row.label, "Firefox");
    // The wrapper's ACTION: line for this selection:
    // `ACTION: launch firefox.desktop Firefox` (exit 0).
    assert_eq!(menu.provider, "launch");
}

#[test]
fn keyseq_esc_chain_clears_then_cancels() {
    let mut menu = fixture_menu();
    let base = run::test_base();
    // Typing then Esc clears the filter (consumed, no exit).
    let outcome = run::replay_keys(&mut menu, &[rune('f'), press(KeyCode::Esc)], base);
    assert_eq!(outcome, KeyOutcome::Consumed);
    assert_eq!(
        menu.app.active_tab().expect("tab").state.filter,
        "",
        "Esc clears the filter first"
    );
    // Empty-filter Esc quits 130 with no stdout.
    let outcome = run::replay_keys(&mut menu, &[press(KeyCode::Esc)], base);
    assert_eq!(outcome, KeyOutcome::Quit(EXIT_CANCELLED));
}

#[test]
fn delete_never_fires_on_launcher_rows() {
    let mut menu = fixture_menu();
    let base = run::test_base();
    let outcome = run::replay_keys(
        &mut menu,
        &[press(KeyCode::Delete), press(KeyCode::Delete)],
        base,
    );
    assert_eq!(outcome, KeyOutcome::Consumed, "Delete is dead on launch");
    assert!(
        !menu.app.active_state().expect("state").confirm_pending,
        "no confirm arms on non-deletable tabs"
    );
}

#[test]
fn legacy_filter_mode_preserves_provider_order() {
    // Anti-score provider order: spec ranks Firefox (100) > My Firm
    // (prefix-word 65) > Confirm (run 45).
    let tab = Tab::with_rows(
        "launch",
        vec![
            Row::new(RowId::new("confirm"), "Confirm"),
            Row::new(RowId::new("firefox"), "Firefox"),
            Row::new(RowId::new("firm"), "My Firm"),
        ],
    );
    let mut menu = flex_rice::menu("launch", vec![tab]);
    menu.app.active_tab_mut().expect("tab").state.filter = "fir".to_string();
    assert_eq!(
        menu.app.visible_rows(),
        vec![1, 2, 0],
        "spec reorders by tier"
    );
    menu.app.filter_mode = flex_core::filter::FilterMode::Legacy;
    assert_eq!(
        menu.app.visible_rows(),
        vec![0, 1, 2],
        "legacy preserves provider order"
    );
}

// --- Launch golden --------------------------------------------------------------

/// Concatenate non-skip symbols of row `y` (exact cell content, no ANSI).
fn row_text(buf: &ratatui::buffer::Buffer, y: u16, w: u16) -> String {
    let mut out = String::new();
    for x in 0..w {
        let cell = buf.cell((x, y)).expect("cell in frame");
        if !cell.skip {
            out.push_str(cell.symbol());
        }
    }
    out
}

#[test]
fn launch_default_view_golden_at_80x24() {
    let mut menu = fixture_menu();
    // Default focus: row 0 (Firefox), empty filter, provider order.
    assert_eq!(
        menu.app.active_tab().expect("tab").state.focus,
        0,
        "default focus is row 0"
    );
    let backend = TestBackend::new(80, 24);
    let mut terminal = Terminal::new(backend).expect("TestBackend terminal");
    terminal
        .draw(|frame| flex_core::render::render(frame, &mut menu))
        .expect("render frame");
    let buf = terminal.backend().buffer().clone();
    // Every row is exactly the frame width in display cells.
    for y in 0..24 {
        let mut x = 0_u16;
        let mut total = 0_usize;
        while x < 80 {
            let cell = buf.cell((x, y)).expect("cell in frame");
            assert!(!cell.skip, "dangling skip cell at ({x}, {y})");
            let symbol_w = width::str_width(cell.symbol());
            total += symbol_w;
            x += u16::try_from(symbol_w.max(1)).expect("row width fits u16");
        }
        assert_eq!(total, 80, "row {y} must be exactly 80 cells");
    }
    // Row 0: selector + Firefox label (bare mode: no filter/hints chrome).
    // The first list row sits below the reserved `•••` indicator line.
    let first_y = flex_core::render::LIST_INDICATOR_ROWS / 2;
    let bar = buf.cell((0, first_y)).expect("bar cell");
    assert_eq!(bar.symbol(), "░");
    assert_eq!(
        bar.fg,
        flex_core::theme::Theme::DEFAULT
            .selector
            .fg
            .expect("selector sets a fg")
    );
    assert!(
        row_text(&buf, first_y, 80).contains("Firefox"),
        "row 0 shows Firefox"
    );
    let mut all = String::new();
    for y in 0..24 {
        all.push_str(&row_text(&buf, y, 80));
    }
    assert!(!all.contains('›'), "bare mode has no filter line");
    assert!(!all.contains("navigate"), "bare mode has no hints line");
}

// --- FLEX_TEST seed extension -----------------------------------------------------

#[test]
fn flex_test_replays_are_deterministic_across_bases() {
    // Same script, different wall-clock bases: identical outcomes and
    // state, because stamps derive from the base + seeded step only.
    assert_ne!(backend::FLEX_TEST_SEED, 0);
    let script = [rune('f'), rune('i'), rune('r'), press(KeyCode::Enter)];
    let run_script = |menu: &mut Menu| {
        let base = run::test_base();
        let mut outcomes = Vec::new();
        for (index, key) in script.iter().enumerate() {
            // Same stamping as `replay_keys`, spelled out for the audit.
            #[allow(clippy::cast_possible_truncation)]
            let step = index as u32;
            outcomes.push(handle_key(menu, *key, base + run::FLEX_TEST_STEP * step));
        }
        outcomes
    };
    let mut first = fixture_menu();
    let mut second = fixture_menu();
    assert_eq!(run_script(&mut first), run_script(&mut second));
    assert_eq!(
        first.app.focused_row().expect("row").id,
        second.app.focused_row().expect("row").id
    );
}

// --- Bash-cache parity probe (manual; needs the live cache) -----------------------

/// Compare the Rust scan against `~/.cache/app-launcher.list`.
///
/// Ignored by default (needs live system state); run explicitly:
/// `cargo test --test launch parity_against_app_cache -- --ignored --nocapture`.
/// Prints both counts plus any name-set drift for the cutover record.
#[test]
#[ignore = "needs live ~/.cache/app-launcher.list + system .desktop dirs"]
fn parity_against_app_cache() {
    let home = std::env::var("HOME").expect("HOME set");
    let cache = PathBuf::from(home).join(".cache/app-launcher.list");
    let text = std::fs::read_to_string(&cache).expect("app-launcher.list readable");
    let mut bash_names: Vec<String> = text
        .lines()
        .filter_map(|line| line.split('\t').next())
        .filter(|name| !name.is_empty())
        .map(str::to_string)
        .collect();
    bash_names.sort();
    let mut rust_names: Vec<String> = launch::load().iter().map(|row| row.label.clone()).collect();
    rust_names.sort();
    println!("bash cache rows: {}", bash_names.len());
    println!("rust scan rows:  {}", rust_names.len());
    let bash_set: std::collections::BTreeSet<&str> =
        bash_names.iter().map(String::as_str).collect();
    let rust_set: std::collections::BTreeSet<&str> =
        rust_names.iter().map(String::as_str).collect();
    let bash_only: Vec<&&str> = bash_set.difference(&rust_set).collect();
    let rust_only: Vec<&&str> = rust_set.difference(&bash_set).collect();
    println!("bash-only names: {bash_only:?}");
    println!("rust-only names: {rust_only:?}");
    assert_eq!(bash_names.len(), rust_names.len(), "row counts must match");
    assert!(
        bash_only.is_empty() && rust_only.is_empty(),
        "name sets must match"
    );
}
