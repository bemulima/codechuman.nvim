#!/usr/bin/env node
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

const taskID = "22222222-2222-4222-8222-222222222222";
const revision = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const root = process.env.CODECHUMAN_NVIM_TEST_ROOT;
const argv = process.argv.slice(2);
const expected = ["open-remote", "--api-base", "https://example.org",
  "--task-instance", taskID, "--root", root, "--token-stdin"];
if (JSON.stringify(argv) !== JSON.stringify(expected) ||
    argv.includes("nvim-smoke-token") || readFileSync(0, "utf8") !== "nvim-smoke-token") {
  process.stderr.write("Neovim did not use the expected secure open-remote stdin contract\n");
  process.exit(2);
}

const directory = join(root, "go-basics", "03");
const materialsDirectory = join(directory, ".learning", "materials", revision);
mkdirSync(dirname(materialsDirectory), { recursive: true, mode: 0o700 });
mkdirSync(materialsDirectory, { recursive: true, mode: 0o700 });
writeFileSync(join(directory, ".learning", "manifest.json"), JSON.stringify({
  schema: "codechuman.checkout.v1", course_id: "88888888-8888-4888-8888-888888888888",
  course_slug: "go-basics", lesson_id: "99999999-9999-4999-8999-999999999999",
  lesson_number: 3, lesson_revision: revision, task_instance_id: taskID,
  sandbox_id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
}));
writeFileSync(join(materialsDirectory, "lesson.md"), "# Authorized Neovim lesson\n\nRead-only material.\n");
writeFileSync(join(directory, "app.js"), "// student starter\n");
process.stdout.write(JSON.stringify({ directory, materials_directory: materialsDirectory }) + "\n");
