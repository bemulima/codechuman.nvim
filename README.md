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

## Teacher chat through Gateway and Dialog

Open a file inside an authorized checkout (lesson/task/example or main.go), then
run `:CodechumanTeacher`. Supply a short-lived Student token at the hidden
prompt. The side panel reads the existing task-bound conversation from Dialog.
Press `s` to ask a question, `r` to refresh, `q` to close and clear the in-memory
token. `:CodechumanAsk` opens the same question prompt; text passed as command
arguments may enter your editor command history, so prefer the prompt.

The token is kept only for this open panel, passed through CLI stdin, never
saved in project/config/history. The server verifies actual TaskInstance
ownership and derives LearningAction identity. By default the chat uses only the Runtime-owned frozen task/step. Set
`teacher_sync_main = true` explicitly in your trusted user config to upload
only the saved regular UTF-8 `main.go` (up to 16 KiB) to the owner-bound Sandbox
before each question. Use `:write` first; unsaved editor changes are excluded.
A missing real V2 Sandbox binding, stale fence, upload error, or readback mismatch
stops the question. No directory traversal or environment/private files are
uploaded. The server must separately enable its default-OFF Teacher workspace
projection; it reads a committed Sandbox generation when processing the question,
not a Submission snapshot. Concurrent saves may advance that generation. Dialog remains the only
canonical conversation store. Pending responses may be refreshed without
resending the question. AI responses are advisory and cannot award mastery.

When lazy-loading the plugin by command, add `CodechumanTeacher` and
`CodechumanAsk` to the plugin spec's `cmd` list. Source tests include
`nvim --headless -u NONE -l test/native_teacher.lua` for token/session boundary
and plain-text rendering. Real provider execution requires explicit isolated
runtime authorization.

### Sandbox run/check and Teacher (IDE28 stand)

Trusted user configuration may opt in with `teacher_checks_enabled = true` and `teacher_sync_main = true`. Both default false. In a task checkout, `:write`, then `:CodechumanCheck` (alias `:CodechumanRun`) executes saved main.go and public HTTP checks through Gateway/Sandbox. In the Teacher panel `t` runs checks, `s` asks Teacher, `r` reloads Dialog. A Student token is requested once per panel and kept in memory only; closing the panel clears it. No automatic model request is sent by Run/Check.

PASS/FAIL are advisory, ERROR is technical, STALE requires another check. The operation does not submit a solution or advance official progress. This bounded profile supports only main.go HTTP health exercises, not arbitrary Go programs. Teacher sees the latest matching Sandbox receipt and code when you ask.

`:CodechumanSubmit` (Teacher panel `u`) is an explicit official Practice submission. Choose milestone/final and confirm; it may freeze editing and change server-owned progress. Run/Check never invokes it. Unconfirmed/VALIDATING results retain their original key/scope/milestone for replay without uploading different code. A timeout is not PASS. Closing a panel discards its in-memory operation state; retain any unconfirmed receipt/key before starting another official operation.

### Saved main.go auto sync (opt-in)

From the task main.go, run `:CodechumanSyncSaved` for an explicit upload and
atomic server ACK. Then `:CodechumanAutoSyncEnable` enables a one-second debounce
on saved main.go only. It never commits/pushes Git, invokes AI, runs checks or
submits automatically. A changed/missing fence, rejected ACK, configuration
change or connection failure stops sync and preserves local code. Review the
remote state before another explicit manual upload.

Run `:CodechumanAutoSyncDisable` before Teacher questions, Run/Check or official
Submit. Disabling stops the queue and forgets the sync token. Tokens are prompted
locally and sent through CLI stdin only; no credentials are written to config.
Existing Teacher operations continue to use their separate temporary session.
