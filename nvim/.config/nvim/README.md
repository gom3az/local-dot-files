# spring-kotlin-neovim

Neovim configuration for Spring (Java/Kotlin) development, forked from [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim).

Built on nvim's native features (LSP, treesitter, statusline) with a small set of
plugins kept where they add real value. No lazy.nvim / no plugin manager — packs are managed
via `vim.pack.add` + the built-in `vim.pack.update()`.

## Requirements

- Neovim 0.12+
- Nerd Font (optional, for icons)
- `make` (optional, for telescope-fzf-native)

## Quick Start

```bash
git clone https://github.com/gom3az/spring-kotlin-neovim.git ~/.config/nvim
nvim --headless "+lua vim.pack.update()" +qa
```

Packs install from `nvim-pack-lock.json` on first launch. LSP servers and DAP adapters
install via Mason on first file open (`:Mason` to manage).

## Structure

```
~/.config/nvim/
├── init.lua              # Entry point
├── lua/config/
│   ├── foundation.lua    # Global options, leaders, base keymaps
│   ├── autocmds.lua      # Yank highlight, etc.
│   ├── pack-hooks.lua    # PackChanged build hooks (fzf-native)
│   ├── nvim-hl.lua       # Highlight palette (used by statusline)
│   └── terminal.lua      # Quick terminal commands (optional, disabled)
├── lua/plugins/          # One file per pack / pack group
│   ├── init.lua          # Requires all plugin modules
│   ├── catppuccin.lua    # Colorscheme
│   ├── cmp.lua           # blink.cmp completion
│   ├── dap.lua           # nvim-dap + dap-ui (Kotlin/Java DAP config)
│   ├── java.lua          # nvim-java (jdtls, DAP, test runner)
│   ├── kotlin-module.lua # Local kotlin-module.nvim (<leader>km)
│   ├── kulala.lua        # REST client (.http files)
│   ├── lsp.lua           # Mason, native vim.lsp config, LspAttach keymaps
│   ├── telescope.lua     # Telescope + fzf-native + ui-select
│   ├── neo-tree.lua      # Neo-tree explorer (<leader>e)
│   └── ...               # bufferline, gitsigns, guess-indent, mini, neogit,
│                         # nui, nvim-nio, plenary, which-key
├── lua/statusline.lua    # Native statusline
├── lua/formatting.lua    # Native format-on-save (LSP + jq)
├── lua/todos.lua         # Native TODO/FIXME keyword highlighting
├── lua/treesitter.lua    # Native treesitter (fold + FileType attach)
├── lua/utils.lua         # gh() URL helper
├── nvim-pack-lock.json   # Pack lock file
└── stylua.toml           # Lua formatter config
```

## Features

- **Java / Kotlin IDE** — `kotlin-lsp` (mason), nvim-java (jdtls), spring-boot.nvim
- **New Kotlin module** — `kotlin-module.nvim` (local plugin), `<leader>km`
- **Debugging** — nvim-dap with Kotlin + Java DAP configurations
- **REST Client** — kulala.nvim (`.http` file support, like IntelliJ HTTP Client)
- **Autocomplete** — blink.cmp
- **Search** — Telescope with fzf-native fuzzy matcher
- **Git** — neogit (Git UI), diffview, gitsigns
- **UI** — catppuccin colorscheme, native statusline, neo-tree explorer, bufferline tabs
- **Highlighting** — native treesitter (`vim.treesitter.start`), native TODO keywords
- **Formatting** — native format-on-save (LSP provider, else jq)

## Keymaps

`<space>` is leader.

### Window navigation
| Key | Action |
| --- | --- |
| `<C-h>` `<C-l>` `<C-j>` `<C-k>` | Move focus left / right / down / up |

### Explorer
| Key | Action |
| --- | --- |
| `<leader>e` | Toggle neo-tree explorer |

### Search (Telescope)
| Key | Action |
| --- | --- |
| `<leader>sf` | Find files |
| `<leader><leader>` | Find files |
| `<leader>sg` | Live grep |
| `<leader>sw` | Grep current word |
| `<leader>s/` | Grep in open files |
| `<leader>sb`/`<leader>fb` | Buffers |
| `<leader>sd` | Diagnostics |
| `<leader>sk` | Keymaps |
| `<leader>sh` | Help tags |
| `<leader>sr` | Resume |
| `<leader>s.` | Recent files |
| `<leader>sc` | Commands |
| `<leader>/` | Fuzzily search current buffer |
| `<leader>sn` | Find files in Neovim config |

### LSP (`gr` = LSP Actions group)
| Key | Action |
| --- | --- |
| `grd` | Goto definition |
| `grr` | References |
| `gri` | Implementation |
| `grt` | Type definition |
| `grD` | Declaration |
| `grn` | Rename |
| `gra` | Code action |
| `gO` / `gW` | Document / workspace symbols |
| `<leader>th` | Toggle inlay hints |

### Git
| Key | Action |
| --- | --- |
| `<leader>gb` | Git branches |

### Diagnostics
| Key | Action |
| --- | --- |
| `<leader>q` | Open diagnostic quickfix list |

### Code
| Key | Action |
| --- | --- |
| `<leader>cf` | Format buffer |
| `<leader>cJ` | Format JSON (`%!jq .`) |
| `<leader>p` | Paste without yanking (visual) |

### Debug
| Key | Action |
| --- | --- |
| `<leader>dt` | Toggle breakpoint |
| `<leader>dc` | Continue |
| `<leader>di` / `<leader>do` / `<leader>dO` | Step into / over / out |

## Plugins (30)

### Java / Spring
- `nvim-java` + `nvim-java-core` — jdtls wrapper, project config
- `spring-boot.nvim` — Spring Boot support
- `nvim-java-dap` + `nvim-java-test` — Java debug + test runner
- `kotlin-module.nvim` — local plugin, scaffold new Kotlin modules (not a pack)

### LSP Infrastructure
- `nvim-lspconfig` — LSP configuration
- `mason.nvim` — LSP/DAP server installer
- `mason-nvim-dap.nvim` — Debug adapter installer

### Autocomplete
- `blink.cmp` + `blink.lib` — Completion engine

### UI
- `catppuccin/nvim` — Colorscheme (pack dir installed as `nvim`)
- `bufferline.nvim` — Tab line
- `mini.nvim` — Pairs, ai, surround, starter modules
- `which-key.nvim` — Keymap popup

### Search & Navigation
- `telescope.nvim` + `plenary.nvim` — Fuzzy finder
- `telescope-fzf-native.nvim` — Rust fuzzy matcher
- `telescope-ui-select.nvim` — Better `vim.ui.select`
- `guess-indent.nvim` — Auto indentation detection

### Git
- `neogit` — Git UI (commit, status, etc.)
- `diffview.nvim` — Diff viewer
- `gitsigns.nvim` — Gutter signs, blame

### Debugging
- `nvim-dap` + `nvim-dap-ui` + `nvim-dap-virtual-text` — Debug adapter, UI, inline values

### REST Client
- `kulala.nvim` — HTTP request file support

### Async (dependency)
- `lua-async-await` — Dependency of nvim-java
- `nui.nvim` / `nvim-nio` — Dependencies of dap-ui / java tooling

### Treesitter (dormant data pack)
- `nvim-treesitter` — installed but never loaded; provides the highlight/fold query
  files nvim's native `vim.treesitter.start` consumes for languages nvim doesn't bundle
  (kotlin, java, zsh, tmux, …). Its `plugin/` only registers `:TSInstall`/`:TSUpdate`.

## Replaced with native equivalents

Removed during the plugin→native migration, replaced by nvim built-ins:
- **lualine** → native statusline (`lua/statusline.lua`)
- **conform.nvim** → native format-on-save (`lua/formatting.lua`)
- **nvim-treesitter (loaded)** → `vim.treesitter.start` (`lua/treesitter.lua`); query data
  still provided by the dormant pack
- **todo-comments.nvim** → `syntax match` keywords (`lua/todos.lua`)