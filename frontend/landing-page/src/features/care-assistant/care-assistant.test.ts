import assert from "node:assert/strict";
import { test } from "node:test";
import { parseAssistantReply, parseMessage, parseRecommendation } from "./contract.ts";
import { handleAssistantRequest } from "./server.ts";
import { requestRecommendation } from "./client.ts";

const message = "Mẹ tôi cần hỗ trợ ăn uống buổi sáng.";
const valid = { serviceCategory: "Chăm sóc người cao tuổi", hours: 4,
  summary: "Hỗ trợ sinh hoạt buổi sáng.", nextStep: "Gửi nhu cầu tư vấn." };
const recommendation = {
  intent: "recommendation",
  title: "Hỗ trợ buổi sáng cho người cao tuổi",
  ...valid,
};
const explanation = {
  intent: "explanation",
  title: "CareSitter hoạt động như thế nào?",
  summary: "CareSitter kết nối gia đình với caregiver đã xác minh cho nhu cầu chăm sóc phi y tế tại nhà.",
  nextStep: "Bạn có thể hỏi về quy trình đặt ca, caregiver hoặc cách theo dõi ca chăm sóc.",
  serviceCategory: null,
  hours: null,
};
const clarification = {
  intent: "clarification",
  title: "Mình chưa hiểu rõ câu hỏi",
  summary: "Bạn có thể nói rõ người thân cần hỗ trợ việc gì hoặc hỏi CareSitter hoạt động như thế nào.",
  nextStep: "Ví dụ: Mẹ tôi cần người đồng hành buổi sáng.",
  serviceCategory: null,
  hours: null,
};
const request = (body: unknown) => new Request("https://care.example/api/care-assistant", {
  method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body),
});

test("null, arrays, wrong types and out-of-range messages return 400 without calling provider", async () => {
  let calls = 0;
  for (const input of [null, [], {}, 12, "text", { message: 4 }, { message: "x" }, { message: "ab" },
    { message: "x".repeat(1201) }]) {
    const result = await handleAssistantRequest(request(input), async () => { calls++; return valid; });
    assert.equal(result.status, 400);
  }
  assert.equal(calls, 0);
  assert.equal(parseMessage({ message: ` ${message} ` }), message);
});

test("malformed JSON returns 400; missing configuration returns 503 for valid input", async () => {
  assert.equal((await handleAssistantRequest(new Request("https://care.example", {
    method: "POST", body: "{broken",
  }), undefined)).status, 400);
  assert.equal((await handleAssistantRequest(request({ message }), undefined)).status, 503);
});

test("provider response is checked, normalized and stripped of extra fields", async () => {
  const response = await handleAssistantRequest(request({ message: ` ${message} ` }), async (text, signal) => {
    assert.equal(text, message);
    assert.equal(signal.aborted, false);
    return { ...recommendation, summary: ` ${valid.summary} `, privateData: "discard" };
  });
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("Cache-Control"), "no-store");
  assert.deepEqual(await response.json(), { reply: recommendation });
});

test("assistant accepts explanations and asks for clarification instead of forcing a service", async () => {
  assert.deepEqual(parseAssistantReply(explanation), explanation);
  assert.deepEqual(parseAssistantReply(clarification), clarification);

  for (const reply of [explanation, clarification]) {
    const response = await handleAssistantRequest(request({ message: "A xi nô" }), async () => reply);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { reply });
  }
});

test("invalid provider contracts and provider failures cannot become success", async () => {
  for (const output of [null, [], {}, { ...valid, hours: "4" }, { ...valid, hours: 1 },
    { ...valid, hours: 13 }, { ...valid, hours: 2.5 }, { ...valid, summary: " " },
    { ...valid, nextStep: "x".repeat(1001) }, { ...valid, serviceCategory: "unknown" }]) {
    assert.equal(parseRecommendation(output), null);
    assert.equal((await handleAssistantRequest(request({ message }), async () => output)).status, 502);
  }
  const failure = await handleAssistantRequest(request({ message }), async () => { throw new Error("private provider data"); });
  assert.equal(failure.status, 502);
  assert.ok(!(await failure.text()).includes("private provider data"));
});

test("client validates success and preserves cancellation signal", async () => {
  const controller = new AbortController();
  assert.deepEqual(await requestRecommendation(message, controller.signal, async (_url, init) => {
    assert.equal(init?.signal, controller.signal);
    assert.deepEqual(JSON.parse(String(init?.body)), { message });
    return Response.json({ reply: recommendation });
  }), recommendation);
  for (const response of [Response.json({ reply: null }), Response.json({ reply: recommendation }, { status: 502 })])
    await assert.rejects(requestRecommendation(message, controller.signal, async () => response));
});
