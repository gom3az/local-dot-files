//! Providers: each parses one subprocess's stdout once into `Vec<Row>`.
//!
//! This is the rice-specific half of flex: every provider reads this
//! machine's tools and `$HOME` conventions, and every provider's action is
//! executed by the matching shell wrapper in `wrappers/`, never here.

#[path = "providers/theme_.rs"]
pub mod theme_;

pub mod center;
pub mod clip;
pub mod launch;
pub mod power;
pub mod shot;
pub mod wallpaper;
pub mod wifi;

use flex_core::{Menu, Tab, TickHook};

/// Per-tick refresh for the two providers whose rows go stale while the menu
/// is open: `center` re-reads volume/brightness into its gauge in place, and
/// `wifi` swaps in a background scan once it finishes.
///
/// Installed by [`menu`]; filter, focus and scroll survive both refreshes.
pub fn tick_hook(menu: &mut Menu) {
    if menu.provider == center::PROVIDER {
        center::refresh_gauges(menu);
    }
    if menu.provider == wifi::PROVIDER {
        wifi::refresh_scan(menu);
    }
}

/// [`Menu::new`] with [`tick_hook`] installed.
///
/// Use this instead of `Menu::new` anywhere in this crate: the engine has no
/// knowledge of which providers need refreshing, so a menu built without the
/// hook would silently stop updating gauges and Wi-Fi scans.
#[must_use]
pub fn menu(provider: impl Into<String>, tabs: Vec<Tab>) -> Menu {
    let hook: TickHook = tick_hook;
    Menu::new(provider, tabs).on_tick(hook)
}
