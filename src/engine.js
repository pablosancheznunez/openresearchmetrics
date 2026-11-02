// Computes each indicator of the catalog from normalized evidence. Pure: the
// same evidence always gives the same report.
//
// Every procedure is tied to the methodology_version it implements. A catalog
// card whose version has no matching procedure is refused, so a definition can
// never change without its code (both are high-risk paths).

export const REPORT_SCHEMA = "orm-report/1";

const PUBLICATION_TYPES = ["article", "review", "book", "book-chapter", "conference-paper"];
const isPublication = (e) => e.source === "openalex" && PUBLICATION_TYPES.includes(e.type);
const isDataOrSoftware = (e) => e.source === "datacite" && ["Dataset", "Software", "ComputationalNotebook"].includes(e.type);

// Each procedure returns { numerator: items[], denominator: items[] | null }.
export const PROCEDURES = {
  "oa-publications-share@1.0.0": (ev) => {
    const pubs = ev.filter(isPublication);
    return { numerator: pubs.filter((e) => e.is_oa === true), denominator: pubs };
  },
  "oa-repository-share@1.0.0": (ev) => {
    const pubs = ev.filter(isPublication);
    return { numerator: pubs.filter((e) => e.repository_fulltext === true), denominator: pubs };
  },
  "openaire-open-access-right-share@1.0.0": (ev) => {
    const all = ev.filter((e) => e.source === "openaire");
    return { numerator: all.filter((e) => e.access_right === "OPEN ACCESS"), denominator: all };
  },
  "datasets-shared@1.0.0": (ev) => ({ numerator: ev.filter((e) => e.source === "datacite" && e.type === "Dataset"), denominator: null }),
  "software-shared@1.0.0": (ev) => ({ numerator: ev.filter((e) => e.source === "datacite" && ["Software", "ComputationalNotebook"].includes(e.type)), denominator: null }),
  "shared-outputs-cited-share@1.0.0": (ev) => {
    const shared = ev.filter(isDataOrSoftware);
    return { numerator: shared.filter((e) => (e.citations ?? 0) > 0), denominator: shared };
  },
  "data-software-per-publication@1.0.0": (ev) => ({ numerator: ev.filter(isDataOrSoftware), denominator: ev.filter(isPublication) }),
  "preprints-share@1.0.0": (ev) => {
    const all = ev.filter((e) => e.source === "openalex");
    return { numerator: all.filter((e) => e.type === "preprint"), denominator: all };
  },
  "study-registrations@1.0.0": (ev) => ({ numerator: ev.filter((e) => e.source === "datacite" && e.type === "StudyRegistration"), denominator: null }),
};

export const procedureKey = (indicator) => `${indicator.id}@${indicator.methodology_version}`;

const round = (x) => Math.round(x * 1000) / 1000;

export function computeIndicator(indicator, evidence, consulted) {
  const procedure = PROCEDURES[procedureKey(indicator)];
  if (!procedure) throw new Error(`No procedure implements ${procedureKey(indicator)}`);
  const base = { id: indicator.id, family: indicator.family, methodology_version: indicator.methodology_version };
  const failed = indicator.sources.filter((s) => !consulted.some((c) => c.source === s && c.ok));
  if (failed.length) {
    return { ...base, status: "unverifiable", reason: `Source unavailable: ${failed.join(", ")}`, value: null, numerator: null, denominator: null, evidence: [] };
  }
  const { numerator, denominator } = procedure(evidence);
  if (denominator === null) {
    return { ...base, status: "computed", reason: null, value: numerator.length, numerator: numerator.length, denominator: null, evidence: numerator };
  }
  if (denominator.length === 0) {
    return { ...base, status: "unverifiable", reason: "Nothing to count in the sources consulted (denominator is zero).", value: null, numerator: 0, denominator: 0, evidence: [] };
  }
  return { ...base, status: "computed", reason: null, value: round(numerator.length / denominator.length), numerator: numerator.length, denominator: denominator.length, evidence: numerator };
}

export function assess({ catalog, evidence, consulted, orcid = null, generatedAt }) {
  return {
    schema: REPORT_SCHEMA,
    catalog_version: catalog.catalog_version,
    orcid,
    generated_at: generatedAt,
    sources_consulted: consulted,
    indicators: catalog.indicators.map((ind) => computeIndicator(ind, evidence, consulted)),
  };
}

// One row per indicator, for CSV export. No column combines indicators.
export function reportRows(report) {
  return report.indicators.map((r) => ({ indicator: r.id, family: r.family, status: r.status, value: r.value, numerator: r.numerator, denominator: r.denominator, methodology_version: r.methodology_version, reason: r.reason }));
}

export function toCsv(rows) {
  if (!rows.length) return "";
  const cols = Object.keys(rows[0]);
  const cell = (v) => {
    const s = v == null ? "" : String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  return [cols.join(","), ...rows.map((r) => cols.map((c) => cell(r[c])).join(","))].join("\n") + "\n";
}
