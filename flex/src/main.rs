//! `flex` binary: parse `power|launch|shot|theme|clip|center|wallpaper|wifi`
//! and print one `ACTION:` line. All providers run the full TUI event loop
//! (`run::run`); thin `wrappers/*.sh` scripts own the side effects.

use anyhow::Result;
use clap::{Parser, Subcommand};
use flex::backend::{EXIT_CANCELLED, EXIT_ERROR};
use flex::{CharSet, CharSetName, Menu, Peaks, Theme, ThemeName};

/// Reusable TUI menu: select a row, print `ACTION:`, let wrappers act.
#[derive(Debug, Parser)]
#[command(name = "flex", version, about = "Reusable TUI menu library")]
struct Cli {
    /// Ranking engine override (R1 escape hatch; `legacy` preserves
    /// provider order instead of score-reordering).
    #[arg(long, hide = true, default_value = "spec", global = true)]
    filter_mode: FilterModeArg,

    /// Character set (upstream `-s/--char-set`): default, compat, extracompat.
    #[arg(
        short = 's',
        long,
        default_value = "default",
        value_parser = parse_char_set,
        global = true
    )]
    char_set: CharSetName,

    /// Theme (upstream `-t/--theme`): default, nocolor, plain.
    #[arg(
        short = 't',
        long,
        default_value = "default",
        value_parser = parse_theme,
        global = true
    )]
    theme: ThemeName,

    /// Peak meters (upstream `-p/--peaks`): off, mono, auto.
    #[arg(
        short = 'p',
        long,
        default_value = "auto",
        value_parser = parse_peaks,
        global = true
    )]
    peaks: Peaks,

    /// Which menu provider to show.
    #[command(subcommand)]
    command: Command,
}

/// Parse an upstream character-set name.
fn parse_char_set(name: &str) -> Result<CharSetName, String> {
    CharSetName::parse(name).ok_or_else(|| {
        format!("'{name}' is not a built-in character set (default, compat, extracompat)")
    })
}

/// Parse an upstream theme name.
fn parse_theme(name: &str) -> Result<ThemeName, String> {
    ThemeName::parse(name)
        .ok_or_else(|| format!("'{name}' is not a built-in theme (default, nocolor, plain)"))
}

/// Parse an upstream peaks mode.
fn parse_peaks(name: &str) -> Result<Peaks, String> {
    match name {
        "off" => Ok(Peaks::Off),
        "mono" => Ok(Peaks::Mono),
        "auto" => Ok(Peaks::Auto),
        other => Err(format!("'{other}' is not a peaks mode (off, mono, auto)")),
    }
}

/// Hidden ranking-engine flag values.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, clap::ValueEnum)]
enum FilterModeArg {
    /// Tiered fuzzy (default).
    #[default]
    Spec,
    /// Subsequence predicate, provider order preserved.
    Legacy,
}

/// Menu providers (each becomes an `ACTION: <provider> …` line).
#[derive(Debug, Subcommand)]
enum Command {
    /// Power menu (shutdown/reboot/…).
    Power,
    /// Application launcher.
    Launch,
    /// Screenshot flow.
    Shot,
    /// Theme switcher.
    Theme,
    /// Clipboard history.
    Clip {
        /// Resolve a content-hash id to its stored (`<NEWLINE>`-encoded)
        /// line. Hidden wrapper lookup: `flex-clip.sh` resolves the hash
        /// from the `ACTION:` line back to content AFTER the TUI exits.
        #[arg(long, hide = true)]
        resolve: Option<String>,
    },
    /// Control center (volume/brightness/network).
    Center,
    /// Wallpaper picker (image previews).
    Wallpaper {
        /// Resolve a path-hash id to its absolute wallpaper path. Hidden
        /// wrapper lookup: `flex-wallpaper.sh` resolves the id from the
        /// `ACTION:` line back to a path AFTER the TUI exits.
        #[arg(long, hide = true)]
        resolve: Option<String>,
    },
    /// Wi-Fi picker (connect/disconnect, radio on/off).
    Wifi,
}

fn main() {
    if let Err(err) = run() {
        eprintln!("flex: error: {err:#}");
        std::process::exit(EXIT_ERROR);
    }
}

/// Parse args and dispatch to the provider.
///
/// Every provider runs the interactive loop (diverging via `process::exit`
/// on a terminal outcome); wrappers own the side effects.
///
/// # Errors
///
/// Returns an error when the event loop reports a TTY failure.
fn run() -> Result<()> {
    let cli = Cli::parse();
    let filter_mode = match cli.filter_mode {
        FilterModeArg::Spec => flex::filter::FilterMode::Spec,
        FilterModeArg::Legacy => flex::filter::FilterMode::Legacy,
    };
    // Global presentation flags apply to every provider, like upstream's
    // `-s/-t/-p` options.
    let style = StyleOptions {
        filter_mode,
        char_set: cli.char_set,
        theme: cli.theme,
        peaks: cli.peaks,
    };
    match cli.command {
        Command::Power => {
            let tab = flex::providers::power::power_tab();
            let menu = style.apply(Menu::new(flex::providers::power::PROVIDER, vec![tab]));
            flex::run::run(menu)?;
            Ok(())
        }
        Command::Launch => {
            let tab = flex::providers::launch::launch_tab();
            if tab.rows.is_empty() {
                eprintln!("flex: launch: no applications found");
            }
            let menu = style.apply(Menu::new(flex::providers::launch::PROVIDER, vec![tab]));
            flex::run::run(menu)?;
            Ok(())
        }
        Command::Shot => {
            let tab = flex::providers::shot::shot_tab();
            let menu = style.apply(Menu::new(flex::providers::shot::PROVIDER, vec![tab]));
            flex::run::run(menu)?;
            Ok(())
        }
        Command::Theme => {
            let tab = flex::providers::theme_::theme_tab();
            if tab.rows.is_empty() {
                eprintln!("flex: theme: no available themes found");
            }
            let menu = style.apply(Menu::new(flex::providers::theme_::PROVIDER, vec![tab]));
            flex::run::run(menu)?;
            Ok(())
        }
        Command::Clip { resolve } => {
            if let Some(hash) = resolve {
                let Some(line) = flex::providers::clip::resolve(&hash) else {
                    anyhow::bail!("flex: clip: unknown id '{hash}'");
                };
                println!("{line}");
                Ok(())
            } else {
                let tab = flex::providers::clip::clip_tab();
                if tab.rows.is_empty() {
                    eprintln!("flex: clip: no history yet");
                    std::process::exit(EXIT_CANCELLED);
                }
                let menu = style.apply(Menu::new(flex::providers::clip::PROVIDER, vec![tab]));
                flex::run::run(menu)?;
                Ok(())
            }
        }
        Command::Center => {
            let menu = style.apply(flex::providers::center::center_menu());
            flex::run::run(menu)?;
            Ok(())
        }
        Command::Wallpaper { resolve } => {
            if let Some(id) = resolve {
                let Some(path) = flex::providers::wallpaper::resolve(&id) else {
                    anyhow::bail!("flex: wallpaper: unknown id '{id}'");
                };
                println!("{}", path.display());
                Ok(())
            } else {
                let tab = flex::providers::wallpaper::wallpaper_tab();
                if tab.rows.is_empty() {
                    eprintln!("flex: wallpaper: no wallpapers found");
                    std::process::exit(EXIT_CANCELLED);
                }
                let mut menu =
                    style.apply(Menu::new(flex::providers::wallpaper::PROVIDER, vec![tab]));
                // Image previews need a kitty-compatible terminal; everywhere
                // else the picker is a plain list (no pane reserved).
                menu.preview = flex::preview::enabled();
                flex::run::run(menu)?;
                Ok(())
            }
        }
        Command::Wifi => {
            let menu = style.apply(flex::providers::wifi::menu());
            flex::run::run(menu)?;
            Ok(())
        }
    }
}

/// Presentation flags shared by every provider (upstream `-s/-t/-p/--filter-mode`).
#[derive(Debug, Clone, Copy)]
struct StyleOptions {
    filter_mode: flex::filter::FilterMode,
    char_set: CharSetName,
    theme: ThemeName,
    peaks: Peaks,
}

impl StyleOptions {
    /// Apply the flags to a menu.
    fn apply(self, mut menu: Menu) -> Menu {
        menu.app.filter_mode = self.filter_mode;
        menu.char_set = CharSet::get(self.char_set);
        menu.theme = Theme::get(self.theme);
        menu.peaks = self.peaks;
        menu
    }
}
