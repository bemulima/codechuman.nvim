import assert from "node:assert/strict";
import { chmodSync, copyFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

const repo = dirname(dirname(fileURLToPath(import.meta.url)));

test("native Neovim executes checkout through an authenticated CLI stdin pipe", () => {
  const sandbox = mkdtempSync(join(tmpdir(), "codechuman-nvim-"));
  try {
    const executable = join(sandbox, "codechuman");
    copyFileSync(new URL("./fixtures/checkout_cli_stub.mjs", import.meta.url), executable);
    chmodSync(executable, 0o700);
    const result = spawnSync(process.env.NVIM_BIN || "nvim",
      ["--headless", "-u", "NONE", "-i", "NONE", "-l", join(repo, "test/native_checkout.lua")], {
        cwd: repo, encoding: "utf8", timeout: 15000,
        env: { ...process.env, CODECHUMAN_NVIM_TEST_CLI: executable,
          CODECHUMAN_NVIM_TEST_ROOT: join(sandbox, "cache") },
      });
    if (result.error) throw result.error;
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout + result.stderr, /NATIVE_NVIM_CHECKOUT_PASS/);
  } finally {
    rmSync(sandbox, { recursive: true, force: true });
  }
});

test("native Neovim opens the revision-pinned lesson from open-remote", () => {
  const sandbox = mkdtempSync(join(tmpdir(), "codechuman-nvim-open-"));
  try {
    const executable = join(sandbox, "codechuman");
    copyFileSync(new URL("./fixtures/open_cli_stub.mjs", import.meta.url), executable);
    chmodSync(executable, 0o700);
    const result = spawnSync(process.env.NVIM_BIN || "nvim",
      ["--headless", "-u", "NONE", "-i", "NONE", "-l", join(repo, "test/native_open.lua")], {
        cwd: repo, encoding: "utf8", timeout: 15000,
        env: { ...process.env, CODECHUMAN_NVIM_TEST_CLI: executable,
          CODECHUMAN_NVIM_TEST_ROOT: join(sandbox, "cache") },
      });
    if (result.error) throw result.error;
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout + result.stderr, /NATIVE_NVIM_OPEN_TASK_PASS/);
  } finally {
    rmSync(sandbox, { recursive: true, force: true });
  }
});

for (const [file, marker] of [["native_teacher.lua", "NATIVE_TEACHER_SESSION_SECURITY_PASS"], ["native_check.lua", "NATIVE_SANDBOX_CHECK_PASS"]]) {
 test(`native Neovim ${file}`, () => {
  const result=spawnSync(process.env.NVIM_BIN || "nvim",["--headless","-u","NONE","-i","NONE","-l",join(repo,"test",file)],{cwd:repo,encoding:"utf8",timeout:15000});
  if(result.error)throw result.error;
  assert.equal(result.status,0,result.stderr || result.stdout);
  assert.match(result.stdout+result.stderr,new RegExp(marker));
 });
}
