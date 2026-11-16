import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import luaparse from "luaparse";

for (const filename of ["plugin/codechuman.lua", "lua/codechuman/init.lua", "lua/codechuman/teacher.lua"]) {
  test(`Lua syntax: ${filename}`, () => {
    const source = readFileSync(new URL(`../${filename}`, import.meta.url), "utf8");
    assert.doesNotThrow(() => luaparse.parse(source, { luaVersion: "5.1" }));
  });
}

test("plugin provides the expected public commands", () => {
  const source = readFileSync(new URL("../plugin/codechuman.lua", import.meta.url), "utf8");
  assert.match(source, /CodechumanOpen/);
  assert.match(source, /CodechumanRefresh/);
  assert.match(source, /CodechumanCheckout/);
  assert.match(source, /CodechumanOpenTask/);
  assert.match(source, /nargs = 1/);
});

test("remote checkout uses a temporary secret and CLI stdin pipe without shell arguments", () => {
  const source = readFileSync(new URL("../lua/codechuman/init.lua", import.meta.url), "utf8");
  assert.match(source, /function M\.checkout_remote/);
  assert.match(source, /vim\.fn\.inputsecret\(/);
  assert.match(source, /canonical_uuid\(task_instance_id\)/);
  assert.match(source, /checkout_busy/);
  assert.match(source, /\"--task-instance\", task_instance_id/);
  assert.match(source, /\"--token-stdin\"/);
  assert.match(source, /stdin = true/);
  assert.match(source, /process:write\(token\)/);
  assert.match(source, /process:write\(nil\)/);
  assert.doesNotMatch(source, /\"--token\", token/);
  assert.doesNotMatch(source, /vim\.fn\.system\(/);
});

test("authenticated task open uses open-remote and opens the pinned revision lesson", () => {
  const source = readFileSync(new URL("../lua/codechuman/init.lua", import.meta.url), "utf8");
  assert.match(source, /function M\.open_task\(task_instance_id\)/);
  assert.match(source, /remote_task\(task_instance_id, "open-remote"\)/);
  assert.match(source, /reply\.materials_directory ~= material_root/);
  assert.match(source, /vim\.cmd\("edit " \.\. vim\.fn\.fnameescape\(lesson\)\)/);
  assert.match(source, /function M\.open_task_selected\(\)/);
});

test("panel can read cached lesson, task, quiz and examples without AI", () => {
  const source = readFileSync(new URL("../lua/codechuman/init.lua", import.meta.url), "utf8");
  assert.match(source, /function M\.lesson_selected/);
  assert.match(source, /function M\.task_selected/);
  assert.match(source, /function M\.quiz_selected/);
  assert.match(source, /function M\.examples_selected/);
});
