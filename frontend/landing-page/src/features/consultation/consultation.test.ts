import assert from "node:assert/strict";
import { test } from "node:test";
import { parseConsultation, vietnamToday, type ConsultationDraft } from "./contract.ts";
import { ConsultationSubmission } from "./client.ts";
import { forwardConsultation } from "./server.ts";

const key = "8be9a8fd-6a47-4b0b-a795-a3f188002ae1";
const draft: ConsultationDraft = { contactName: "Gia đình A", phone: "0912345678",
  serviceCategory: "elderly_care", preferredDate: "2027-01-01", hours: 4,
  caregiverPreference: "", note: "", consent: true };
const receipt = (id: string) => ({ id, createdAt: "2026-10-12T10:00:00Z" });
const request = (body: unknown = draft, origin = "https://care.example") =>
  new Request("https://care.example/api/consultation-requests", { method: "POST",
    headers: { origin, "Content-Type": "application/json", "Idempotency-Key": key },
    body: JSON.stringify(body) });

test("validates consent, real dates and contact; uses Vietnam calendar date", () => {
  assert.equal(parseConsultation({ ...draft, consent: false }), null);
  assert.equal(parseConsultation({ ...draft, preferredDate: "2027-02-30" }), null);
  assert.equal(parseConsultation({ ...draft, hours: "4" }), null);
  assert.equal(parseConsultation({ ...draft, phone: "+84 912 345 678" })?.phone, draft.phone);
  assert.equal(vietnamToday(new Date("2026-10-12T18:00:00Z")), "2026-10-13");
});

test("same-origin valid submission forwards only normalized contract and returns a receipt", async () => {
  const response = await forwardConsultation(request({ ...draft, totalPrice: 1, token: "ignored" }),
    "http://backend:5033", async (url, init) => {
      assert.equal(String(url), "http://backend:5033/api/v1/consultation-requests");
      assert.deepEqual(JSON.parse(String(init?.body)), draft);
      assert.equal(new Headers(init?.headers).get("Idempotency-Key"), key);
      return Response.json({ ...receipt(key), phone: "must not be returned" });
    });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), receipt(key));
});

test("invalid origin, contact and missing configuration do not call backend", async () => {
  const unreachable: typeof fetch = async () => { throw new Error("must not call"); };
  assert.equal((await forwardConsultation(request(draft, "https://evil.example"), "http://backend", unreachable)).status, 403);
  assert.equal((await forwardConsultation(request({ ...draft, phone: "" }), "http://backend", unreachable)).status, 400);
  assert.equal((await forwardConsultation(request(), undefined, unreachable)).status, 503);
});

for (const status of [400, 409, 429, 500]) {
  test("backend failure " + status + " never becomes success", async () => {
    const response = await forwardConsultation(request(), "http://backend",
      async () => Response.json({ detail: "internal SQL / personal data" }, { status }));
    assert.equal(response.status, status === 500 ? 502 : status);
    assert.ok(!(await response.text()).includes("internal SQL"));
  });
}

test("unexpected receipt or a lost response stays unconfirmed", async () => {
  assert.equal((await forwardConsultation(request(), "http://backend",
    async () => Response.json({ ok: true }))).status, 502);
  assert.equal((await forwardConsultation(request(), "http://backend",
    async () => { throw new Error("timeout"); })).status, 502);
});

test("double clicks and lost-response retries reuse one key, including a new client instance", async () => {
  let stored: string | null = null;
  const storage = { getItem: () => stored, setItem: (_name: string, value: string) => { stored = value; } };
  const keys: string[] = [];
  let fail = true;
  const fetcher: typeof fetch = async (_url, init) => {
    const currentKey = new Headers(init?.headers).get("Idempotency-Key")!;
    keys.push(currentKey);
    if (fail) throw new Error("response lost");
    return Response.json(receipt(currentKey));
  };
  const client = new ConsultationSubmission(fetcher, storage);
  const first = client.submit(draft);
  assert.equal(client.submit(draft), first);
  await assert.rejects(first);
  fail = false;
  await new ConsultationSubmission(fetcher, storage).submit(draft);
  assert.equal(keys.length, 2);
  assert.equal(keys[0], keys[1]);
  assert.ok(!stored!.includes(draft.phone));
  await client.submit({ ...draft, note: "Nhu cầu mới" });
  assert.notEqual(keys[2], keys[1]);
});

test("client rejects malformed success instead of showing the success view", async () => {
  const client = new ConsultationSubmission(async () => Response.json({ ok: true }));
  await assert.rejects(client.submit(draft), /Chưa xác nhận/);
});
