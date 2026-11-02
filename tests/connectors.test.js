import { test } from "node:test";
import assert from "node:assert/strict";
import { collectEvidence, isValidOrcid, normalizeDatacite, normalizeOpenaire, normalizeOpenalex } from "../src/connectors.js";
import { load } from "./helpers.js";

const KEYS = ["access_right", "citations", "is_oa", "oa_status", "repository_fulltext", "source", "title", "type", "url", "year"].sort();

test("ORCID checksum", () => {
  assert.ok(isValidOrcid("0000-0002-1825-0097"));
  assert.ok(!isValidOrcid("0000-0002-1825-0098"));
});

for (const [name, normalize] of Object.entries({ openalex: normalizeOpenalex, datacite: normalizeDatacite, openaire: normalizeOpenaire })) {
  test(`${name}: recorded response normalizes`, () => {
    const items = normalize(load(`tests/fixtures/${name}.json`));
    assert.ok(items.length > 0);
    for (const it of items) {
      assert.deepEqual(Object.keys(it).sort(), KEYS);
      assert.equal(it.source, name);
    }
  });
}

test("OpenAlex open access fields are carried over", () => {
  const items = normalizeOpenalex(load("tests/fixtures/openalex.json"));
  assert.ok(items.every((i) => typeof i.is_oa === "boolean" && typeof i.oa_status === "string" && typeof i.repository_fulltext === "boolean"));
});

test("a failing source is reported, not fatal", async () => {
  const fetchFn = async (url) => {
    if (url.includes("datacite")) return { ok: false, status: 500, statusText: "Error" };
    const name = url.includes("openalex") ? "openalex" : "openaire";
    return { ok: true, json: async () => load(`tests/fixtures/${name}.json`) };
  };
  const { consulted } = await collectEvidence("0000-0002-1825-0097", { fetchFn, now: () => "t" });
  assert.equal(consulted.find((c) => c.source === "datacite").ok, false);
  assert.equal(consulted.find((c) => c.source === "openalex").ok, true);
});
