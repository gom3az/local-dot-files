# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Packages

| Package | Targets |
|---------|---------|
| `hypr` | `~/.config/hypr` |
| `kitty` | `~/.config/kitty` |
| `lazydocker` | `~/.config/lazydocker` |
| `nvim` | `~/.config/nvim` |
| `themes` | `~/.config/themes` |
| `tmux` | `~/.tmux`, `~/.tmux.conf` |
| `scripts` | `~/.config/scripts` |
| `waybar` | `~/.config/waybar` |
| `wiremix` | `~/.config/wiremix` |
| `zsh` | `~/.zshrc` |

## Setup on a new machine

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
stow hypr kitty nvim scripts themes tmux waybar wiremix zsh
```

## Notification Daemon (`flex-notify`)

`flex-notify` runs as a systemd user daemon providing `org.freedesktop.Notifications`:

```bash
# Systemd user service unit: ~/.config/systemd/user/flex-notify.service
# DBus service file: ~/.local/share/dbus-1/services/org.freedesktop.Notifications.service

systemctl --user daemon-reload
systemctl --user enable --now flex-notify.service
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
