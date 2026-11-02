import { collectEvidence, isValidOrcid } from "./connectors.js";
import { assess, reportRows, toCsv } from "./engine.js";

const $ = (id) => document.getElementById(id);
const catalog = await (await fetch("data/indicators.json")).json();
let lastReport = null;

function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") node.className = v;
    else node.setAttribute(k, v);
  }
  for (const c of children.flat()) node.append(c instanceof Node ? c : document.createTextNode(String(c ?? "")));
  return node;
}

function formatValue(ind, result) {
  if (!result) return null;
  if (result.status === "unverifiable") return el("p", { class: "value" }, `Unverifiable: ${result.reason}`);
  if (result.denominator === null) return el("p", { class: "value" }, String(result.value));
  const ratio = ind.id === "data-software-per-publication";
  const shown = ratio ? result.value.toFixed(2) : `${Math.round(result.value * 100)}%`;
  return el("p", { class: "value" }, shown, el("small", {}, ` ${result.numerator} of ${result.denominator}`));
}

function render(report) {
  $("version").textContent = `Catalog version ${catalog.catalog_version}, valid from ${catalog.valid_from} (${catalog.status}).`;
  const byId = Object.fromEntries((report?.indicators ?? []).map((r) => [r.id, r]));
  $("families").replaceChildren(
    ...catalog.families.map((f) =>
      el("section", { class: "family" },
        el("h2", {}, f.name),
        el("p", { class: "note" }, f.question),
        el("div", { class: "grid" },
          catalog.indicators.filter((i) => i.family === f.id).map((ind) => {
            const r = byId[ind.id];
            return el("article", { class: `card indicator ${r?.status ?? ""}` },
              el("h3", {}, ind.name),
              el("p", { class: "meta" }, ind.definition),
              formatValue(ind, r) ?? "",
              el("details", {},
                el("summary", {}, "How it is computed"),
                el("p", { class: "meta" }, `Numerator: ${ind.numerator}.`, ind.denominator ? ` Denominator: ${ind.denominator}.` : " A count, no denominator."),
                el("p", { class: "meta" }, `Why: ${ind.rationale}`),
                el("ul", { class: "lim" }, ind.limitations.map((l) => el("li", {}, l))),
                el("p", { class: "meta" }, `Methodology ${ind.methodology_version}`),
              ),
              r?.evidence?.length
                ? el("details", {},
                    el("summary", {}, `Evidence (${r.evidence.length})`),
                    el("ul", {}, r.evidence.slice(0, 200).map((e) => el("li", {}, e.url ? el("a", { href: e.url, rel: "noopener" }, e.title || e.url) : e.title, e.year ? ` (${e.year})` : ""))),
                  )
                : "",
            );
          }),
        ),
      ),
    ),
  );
  if (report) {
    $("sources").replaceChildren(...report.sources_consulted.map((c) => el("li", { class: c.ok ? "" : "fail", title: c.error ?? "" }, `${c.source}: ${c.ok ? `${c.count} items` : "no answer"}`)));
    $("results").hidden = false;
  }
}

function download(name, text, type) {
  const a = el("a", { href: URL.createObjectURL(new Blob([text], { type })), download: name });
  a.click();
  URL.revokeObjectURL(a.href);
}

async function run() {
  const orcid = $("orcid").value.trim().replace(/^https?:\/\/orcid\.org\//, "");
  if (!isValidOrcid(orcid)) {
    $("message").textContent = "That is not a valid ORCID iD (16 digits, last one may be X).";
    return;
  }
  history.replaceState(null, "", `#orcid=${orcid}`);
  $("message").textContent = "Querying OpenAlex, DataCite and OpenAIRE…";
  $("form").querySelector("button").disabled = true;
  try {
    const { evidence, consulted } = await collectEvidence(orcid);
    lastReport = assess({ catalog, evidence, consulted, orcid, generatedAt: new Date().toISOString() });
    render(lastReport);
    $("message").textContent = "";
  } catch (err) {
    $("message").textContent = `Something went wrong: ${err.message}`;
  } finally {
    $("form").querySelector("button").disabled = false;
  }
}

$("form").addEventListener("submit", (e) => {
  e.preventDefault();
  run();
});
$("dl-json").addEventListener("click", () => download(`orm-${lastReport.orcid}.json`, JSON.stringify(lastReport, null, 2), "application/json"));
$("dl-csv").addEventListener("click", () => download(`orm-${lastReport.orcid}.csv`, toCsv(reportRows(lastReport)), "text/csv"));

render(null);
const orcid = new URLSearchParams(location.hash.slice(1)).get("orcid");
if (orcid) {
  $("orcid").value = orcid;
  run();
}
