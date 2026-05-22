# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Packages

| Package | Targets |
|---------|---------|
| `hypr` | `~/.config/hypr` |
| `kitty` | `~/.config/kitty` |
| `nvim` | `~/.config/nvim` |
| `rofi` | `~/.config/rofi` |
| `themes` | `~/.config/themes` |
| `tmux` | `~/.tmux`, `~/.tmux.conf` |
| `scripts` | `~/.config/scripts` |
| `waybar` | `~/.config/waybar` |
| `zsh` | `~/.zshrc` |

## Setup on a new machine

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
stow hypr kitty nvim rofi scripts themes tmux waybar zsh
```

## Commands

```bash
stow <package>       # create symlinks
stow -D <package>    # remove symlinks
stow -R <package>    # restow (--D + stow)
```

## Adding a new package

```bash
mkdir -p ~/dotfiles/<pkg>/.config/<app>   # if under ~/.config
mv ~/.config/<app> ~/dotfiles/<pkg>/.config/<app>
cd ~/dotfiles && stow <pkg>
```
