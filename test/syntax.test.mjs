import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import luaparse from "luaparse";

for (const filename of ["plugin/codechuman.lua", "lua/codechuman/init.lua"]) {
  test(`Lua syntax: ${filename}`, () => {
    const source = readFileSync(new URL(`../${filename}`, import.meta.url), "utf8");
    assert.doesNotThrow(() => luaparse.parse(source, { luaVersion: "5.1" }));
  });
}

test("plugin provides the expected public commands", () => {
  const source = readFileSync(new URL("../plugin/codechuman.lua", import.meta.url), "utf8");
  assert.match(source, /CodechumanOpen/);
  assert.match(source, /CodechumanRefresh/);
});

test("panel can read cached lesson, task, quiz and examples without AI", () => {
  const source = readFileSync(new URL("../lua/codechuman/init.lua", import.meta.url), "utf8");
  assert.match(source, /function M\.lesson_selected/);
  assert.match(source, /function M\.task_selected/);
  assert.match(source, /function M\.quiz_selected/);
  assert.match(source, /function M\.examples_selected/);
});
