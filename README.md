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
    branch = "epic/IDE-28", -- remove this line after the branch is merged
    cmd = { "CodechumanOpen", "CodechumanRefresh", "CodechumanCheckout", "CodechumanOpenTask" },
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

### Prerequisites and both distributions

Use Neovim 0.10 or newer, Git, Go 1.24.4 or newer, and the matching Codechuman
CLI binary.

LazyVim and AstroNvim v4 use lazy.nvim plugin specs. For either distribution,
put the snippet in `~/.config/nvim/lua/plugins/codechuman.lua`; with a named
Neovim profile, use that profile's `stdpath('config')/lua/plugins/` directory.
AstroNvim v4 automatically loads plugin specs from `lua/plugins/`. Run
`:Lazy sync` after saving the file.

Build the matching CLI branch once and make it available on `PATH`:

```sh
git clone --branch epic/IDE-28 https://github.com/bemulima/codechuman-cli.git
cd codechuman-cli
mkdir -p "$HOME/.local/bin"
go build -o "$HOME/.local/bin/codechuman" ./cmd/codechuman
```

Ensure `~/.local/bin` is on `PATH`, then restart Neovim. After the server
vertical is integrated and enabled in its approved test environment, open a
real owner-authorized lesson with:

```vim
:CodechumanOpenTask <TaskInstance UUID>
```

Neovim prompts for a temporary Student access token without echoing it; paste
the token from the approved sign-in flow. The CLI receives it on stdin and
opens the lesson at its pinned revision. The client does not perform sign-in
or mint credentials.

Current commands:

- `:CodechumanOpen` — show local task checkouts in a right split.
- `:CodechumanRefresh` — reload the local list.
- `:CodechumanCheckout <TaskInstance UUID>` — authenticated HTTPS starter
  checkout for an existing Student-owned task. Requires the Go CLI from
  `bemulima/codechuman-cli` with `checkout-remote` descriptor v1 support,
  an HTTPS Gateway configured in user plugin options, and a temporary Student
  access token obtained outside Neovim. The token is prompted invisibly, piped
  to the CLI stdin, and never saved by this plugin.
- `:CodechumanOpenTask <TaskInstance UUID>` — fetches the owner-pinned starter
  and public lesson pack with the same one-shot token, verifies/cache-writes
  through `codechuman open-remote`, and opens the exact revision's `lesson.md`
  in Neovim. No Course, Lesson, or role IDs are accepted from the client.
- In the panel: `<Enter>` opens `app.js`; `o` fetches and opens the selected
  TaskInstance lesson; `l` shows the cached `lesson.md`,
  `a` shows `task.md`, `z` shows read-only `quiz.json`, `e` shows
  cached examples, `v` runs JS syntax check, `t` runs opt-in public JS
  tests, `b` returns to the list, and `q` closes it.

Public tests execute JavaScript locally as the student OS user, without a
sandbox. Run only trusted tests. These checks never award official Mastery.

## Verification

```sh
npm ci
npm test
NVIM_BIN=/path/to/nvim npm run test:nvim
```

The default tests parse Lua source and verify the public commands. The optional
`test:nvim` invokes a real Neovim 0.10+ process with isolated mock CLI programs;
it checks the hidden token prompt, exact stdin arguments, duplicate-start guard,
invalid UUID refusal, and opening a revision-scoped lesson beside starter code.
It does not replace installation checks for LazyVim, AstroNvim or an
authenticated live Gateway.

Account sign-in, AI Teacher, live Sandbox sync and official
Submit are **not implemented** in this first slice. `CodechumanCheckout` is a
manual-token preview of the existing server-authorized Git checkout flow, not
in-editor sign-in or a production release. `CodechumanOpenTask` requires the
separate default-off IDE-28 materials endpoint to be integrated and enabled in
an approved test environment. Materials remain in the matching immutable
revision directory; the Sandbox code sync remains the official source workflow.

This public source has no open-source license grant yet.
