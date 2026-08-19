#!/usr/bin/env bash
set -e
nvim --headless -u NONE \
  --cmd "set rtp^=/home/test/dotfiles/nvim/kotlin-module.nvim" \
  -c "lua dofile('/home/test/dotfiles/nvim/kotlin-module.nvim/tests/wizard/wizard_cases.lua')" \
  +qa