# Codechuman for Neovim

Early, **partial** Lua client for Codechuman, using the common Go CLI. It targets
Neovim 0.10+, including current LazyVim and AstroNvim configurations using
`lazy.nvim`.

## Install from GitHub with lazy.nvim

Place the following in `~/.config/nvim/lua/plugins/codechuman.lua` (or the
corresponding `stdpath('config')` when you use another `NVIM_APPNAME`):

```lua
return {
  {
    "bemulima/codechuman.nvim",
    keys = {
      { "<leader>B", "<cmd>CodechumanOpen<CR>", desc = "Codechuman" },
    },
    opts = {
      cli_path = "codechuman",
      workspace_root = vim.fn.expand("~/.codechuman"),
      api_base_url = "https://YOUR-CODECHUMAN-GATEWAY", -- Your trusted HTTPS origin
      width = 46,
    },
  },
}
```

Run `:Lazy sync`, then `<Space>B` when your leader is Space. The key is
configurable to avoid collisions with existing buffer shortcuts.

Current commands:

- `:CodechumanOpen` — show local task checkouts in a right split.
- `:CodechumanRefresh` — reload the local list.
- `:CodechumanCheckout <TaskInstance UUID>` — authenticated HTTPS starter
  checkout for an existing Student-owned task. Requires the Go CLI from
  `bemulima/codechuman-cli` with `checkout-remote` descriptor v1 support,
  an HTTPS Gateway configured in user plugin options, and a temporary Student
  access token obtained outside Neovim. The token is prompted invisibly, piped
  to the CLI stdin, and never saved by this plugin.
- In the panel: `<Enter>` opens `app.js`; `l` shows `lesson.md`,
  `a` shows `task.md`, `z` shows read-only `quiz.json`, `e` shows
  cached examples, `v` runs JS syntax check, `t` runs opt-in public JS
  tests, `b` returns to the list, and `q` closes it.

Public tests execute JavaScript locally as the student OS user, without a
sandbox. Run only trusted tests. These checks never award official Mastery.

## Verification

```sh
npm ci
npm test
```

These tests parse Lua source and verify the public commands. A headless Neovim
runtime test is still needed before release; `luaparse` passing alone does not
prove compatibility with all LazyVim/AstroNvim configurations.

Account sign-in, server-based courses, AI Teacher, live Sandbox sync and official
Submit are **not implemented** in this first slice. `CodechumanCheckout` is a
manual-token preview of the existing server-authorized Git checkout flow, not
in-editor sign-in or a production release. The server may keep routes disabled
until explicitly activated. The CLI checkout contains the pinned Git starter,
not Course lesson/quiz materials, which require separate owner endpoints.

This public source has no open-source license grant yet.
