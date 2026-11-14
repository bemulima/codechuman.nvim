#!/usr/bin/env node
import { readFileSync } from "node:fs";

const taskID = "22222222-2222-4222-8222-222222222222";
const argv = process.argv.slice(2);
const expected = ["checkout-remote", "--api-base", "https://example.org",
  "--task-instance", taskID, "--root", process.env.CODECHUMAN_NVIM_TEST_ROOT,
  "--token-stdin"];

if (JSON.stringify(argv) !== JSON.stringify(expected) ||
    argv.includes("nvim-smoke-token") || readFileSync(0, "utf8") !== "nvim-smoke-token") {
  process.stderr.write("Neovim did not use the expected descriptor-v1 CLI stdin contract\n");
  process.exit(2);
}

process.stdout.write(JSON.stringify({ directory: process.env.CODECHUMAN_NVIM_TEST_ROOT + "/test-checkout" }) + "\n");
