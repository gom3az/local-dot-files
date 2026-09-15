//! Providers (M2): each parses one subprocess's stdout once into `Vec<Row>`.
//!
//! The library never executes the chosen action — wrappers do.

#[path = "providers/theme_.rs"]
pub mod theme_;

pub mod center;
pub mod clip;
pub mod launch;
pub mod power;
pub mod shot;
pub mod wallpaper;
pub mod wifi;
