// Recorded responses for ORCID's public test record must keep producing the
// stored report. The expected file is high risk: only a person regenerates it,
// with UPDATE=1 node --test tests/regression.test.js
import { test } from "node:test";
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
import { normalizeDatacite, normalizeOpenaire, normalizeOpenalex } from "../src/connectors.js";
import { assess } from "../src/engine.js";
import { catalog, load, rootPath } from "./helpers.js";

test("regression: report for the ORCID test record", () => {
  const evidence = [
    ...normalizeOpenalex(load("tests/fixtures/openalex.json")),
    ...normalizeDatacite(load("tests/fixtures/datacite.json")),
    ...normalizeOpenaire(load("tests/fixtures/openaire.json")),
  ];
  const consulted = ["openalex", "datacite", "openaire"].map((source) => ({ source, ok: true, count: evidence.filter((e) => e.source === source).length, error: null, retrieved_at: "2026-11-02T00:00:00Z" }));
  const report = assess({ catalog, evidence, consulted, orcid: "0000-0002-1825-0097", generatedAt: "2026-11-02T00:00:00Z" });
  const file = "tests/regression/carberry.json";
  if (process.env.UPDATE) writeFileSync(rootPath(file), JSON.stringify(report, null, 1) + "\n");
  assert.deepEqual(report, load(file));
});
