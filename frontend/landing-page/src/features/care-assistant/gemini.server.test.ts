import assert from "node:assert/strict";
import { test } from "node:test";
import { generateWithGeminiFallback } from "./gemini.server.ts";

const activeSignal = new AbortController().signal;

test("retries a transient primary failure once, then uses the fallback model", async () => {
  const calls: string[] = [];
  const result = await generateWithGeminiFallback(
    async (model) => {
      calls.push(model);
      if (model === "primary") throw { status: 503 };
      return { model };
    },
    activeSignal,
    {
      models: ["primary", "fallback"],
      retryDelayMs: 0,
      attemptTimeoutMs: 1_000,
    },
  );

  assert.deepEqual(calls, ["primary", "primary", "fallback"]);
  assert.deepEqual(result, { model: "fallback" });
});

test("skips retry for a retired model and falls back immediately", async () => {
  const calls: string[] = [];
  const result = await generateWithGeminiFallback(
    async (model) => {
      calls.push(model);
      if (model === "retired") throw { status: 404 };
      return "ok";
    },
    activeSignal,
    {
      models: ["retired", "fallback"],
      retryDelayMs: 0,
      attemptTimeoutMs: 1_000,
    },
  );

  assert.deepEqual(calls, ["retired", "fallback"]);
  assert.equal(result, "ok");
});

test("does not retry or fall back after caller cancellation", async () => {
  const controller = new AbortController();
  let calls = 0;

  await assert.rejects(
    generateWithGeminiFallback(
      async () => {
        calls++;
        controller.abort();
        throw new DOMException("Aborted", "AbortError");
      },
      controller.signal,
      {
        models: ["primary", "fallback"],
        retryDelayMs: 0,
        attemptTimeoutMs: 1_000,
      },
    ),
    { name: "AbortError" },
  );

  assert.equal(calls, 1);
});
