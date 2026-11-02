import { test } from "node:test";
import assert from "node:assert/strict";
import { PROCEDURES, procedureKey } from "../src/engine.js";
import { catalog } from "./helpers.js";

test("indicator ids are unique", () => {
  const ids = catalog.indicators.map((i) => i.id);
  assert.equal(new Set(ids).size, ids.length);
});

test("every family has at least one indicator and every indicator a known family", () => {
  const families = catalog.families.map((f) => f.id);
  for (const ind of catalog.indicators) assert.ok(families.includes(ind.family), `${ind.id}: unknown family`);
  for (const f of families) assert.ok(catalog.indicators.some((i) => i.family === f), `family ${f} has no indicator`);
});

test("every indicator card has a procedure for its exact methodology version", () => {
  for (const ind of catalog.indicators) assert.ok(PROCEDURES[procedureKey(ind)], `missing procedure ${procedureKey(ind)}`);
});

test("no procedure is left without a card", () => {
  const keys = new Set(catalog.indicators.map(procedureKey));
  for (const k of Object.keys(PROCEDURES)) assert.ok(keys.has(k), `procedure ${k} has no catalog card`);
});

test("no composite score exists in the catalog", () => {
  assert.ok(!catalog.indicators.some((i) => /score|index|composite/i.test(i.id)));
});
