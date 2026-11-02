import { test } from "node:test";
import assert from "node:assert/strict";
import { assess, computeIndicator, reportRows, toCsv } from "../src/engine.js";
import { catalog } from "./helpers.js";

const card = (id) => catalog.indicators.find((i) => i.id === id);
const allOk = ["openalex", "datacite", "openaire"].map((source) => ({ source, ok: true }));
const work = (fields) => ({ source: "openalex", type: "article", title: "t", year: 2020, url: null, is_oa: false, oa_status: "closed", repository_fulltext: false, access_right: null, citations: null, ...fields });
const doi = (type, citations = 0) => ({ source: "datacite", type, title: "d", year: 2021, url: null, is_oa: null, oa_status: null, repository_fulltext: null, access_right: null, citations });

test("open access share counts only publication types", () => {
  const ev = [work({ is_oa: true }), work({ is_oa: true }), work({}), work({ is_oa: true, type: "dataset" })];
  const r = computeIndicator(card("oa-publications-share"), ev, allOk);
  assert.deepEqual([r.status, r.numerator, r.denominator, r.value], ["computed", 2, 3, 0.667]);
});

test("repository share", () => {
  const ev = [work({ repository_fulltext: true }), work({})];
  assert.equal(computeIndicator(card("oa-repository-share"), ev, allOk).value, 0.5);
});

test("counts have no denominator", () => {
  const r = computeIndicator(card("datasets-shared"), [doi("Dataset"), doi("Dataset"), doi("Software")], allOk);
  assert.deepEqual([r.value, r.denominator], [2, null]);
});

test("cited share of shared data and software", () => {
  const r = computeIndicator(card("shared-outputs-cited-share"), [doi("Dataset", 3), doi("Software", 0), doi("JournalArticle", 9)], allOk);
  assert.deepEqual([r.numerator, r.denominator, r.value], [1, 2, 0.5]);
});

test("a zero denominator is unverifiable, never zero", () => {
  const r = computeIndicator(card("oa-publications-share"), [], allOk);
  assert.equal(r.status, "unverifiable");
  assert.equal(r.value, null);
});

test("an unavailable source makes the indicator unverifiable", () => {
  const consulted = [{ source: "openalex", ok: false }, { source: "datacite", ok: true }, { source: "openaire", ok: true }];
  const r = computeIndicator(card("data-software-per-publication"), [doi("Dataset")], consulted);
  assert.equal(r.status, "unverifiable");
  assert.match(r.reason, /openalex/);
});

test("an unknown methodology version is refused", () => {
  assert.throws(() => computeIndicator({ ...card("preprints-share"), methodology_version: "9.0.0" }, [], allOk), /No procedure/);
});

test("report has one entry per indicator and no total", () => {
  const report = assess({ catalog, evidence: [work({ is_oa: true })], consulted: allOk, generatedAt: "t" });
  assert.equal(report.indicators.length, catalog.indicators.length);
  assert.ok(!("score" in report) && !("total" in report));
  const csv = toCsv(reportRows(report));
  assert.equal(csv.trim().split("\n").length, catalog.indicators.length + 1);
});
