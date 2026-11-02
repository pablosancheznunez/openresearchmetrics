// Connectors to OpenAlex, DataCite and the OpenAIRE Graph. Pure normalize
// functions (tested on recorded responses) plus fetch functions for browsers
// and Node 18+. Every item is normalized to:
// { source, type, title, year, url, is_oa, oa_status, repository_fulltext, access_right, citations }

export function isValidOrcid(id) {
  if (!/^\d{4}-\d{4}-\d{4}-\d{3}[\dX]$/.test(id)) return false;
  const digits = id.replace(/-/g, "");
  let total = 0;
  for (const ch of digits.slice(0, 15)) total = (total + Number(ch)) * 2;
  const check = (12 - (total % 11)) % 11;
  return digits[15] === (check === 10 ? "X" : String(check));
}

const item = (fields) => ({
  source: fields.source,
  type: fields.type ?? null,
  title: fields.title ?? null,
  year: Number.isFinite(fields.year) ? fields.year : null,
  url: fields.url ?? null,
  is_oa: fields.is_oa ?? null,
  oa_status: fields.oa_status ?? null,
  repository_fulltext: fields.repository_fulltext ?? null,
  access_right: fields.access_right ?? null,
  citations: Number.isFinite(fields.citations) ? fields.citations : null,
});

export function normalizeOpenalex(json) {
  return (json.results ?? []).map((w) =>
    item({
      source: "openalex",
      type: w.type,
      title: w.title,
      year: w.publication_year,
      url: w.doi ?? w.id,
      is_oa: w.open_access?.is_oa,
      oa_status: w.open_access?.oa_status,
      repository_fulltext: w.open_access?.any_repository_has_fulltext,
    }),
  );
}

export function normalizeDatacite(json) {
  return (json.data ?? []).map((d) => {
    const a = d.attributes ?? {};
    return item({
      source: "datacite",
      type: a.types?.resourceTypeGeneral,
      title: a.titles?.[0]?.title,
      year: a.publicationYear,
      url: a.doi ? `https://doi.org/${a.doi}` : a.url,
      citations: a.citationCount,
    });
  });
}

export function normalizeOpenaire(json) {
  return (json.results ?? []).map((r) => {
    const doi = (r.pids ?? []).find((p) => p.scheme === "doi");
    return item({
      source: "openaire",
      type: r.type,
      title: r.mainTitle,
      year: r.publicationDate ? Number(r.publicationDate.slice(0, 4)) : null,
      url: doi ? `https://doi.org/${doi.value}` : `https://explore.openaire.eu/search/result?id=${encodeURIComponent(r.id)}`,
      access_right: r.bestAccessRight?.label,
    });
  });
}

async function getJson(url, fetchFn) {
  const res = await fetchFn(url, { headers: { Accept: "application/json" } });
  if (!res.ok) throw new Error(`${res.status} ${res.statusText} for ${url}`);
  return res.json();
}

const MAX_PAGES = 5;

export const fetchers = {
  async openalex(orcid, fetchFn) {
    // Basic paging: OpenAlex requires an API key for cursor paging.
    const items = [];
    for (let page = 1; page <= MAX_PAGES; page++) {
      const json = await getJson(`https://api.openalex.org/works?filter=author.orcid:${orcid}&per-page=200&page=${page}&select=id,doi,title,type,publication_year,open_access`, fetchFn);
      items.push(...normalizeOpenalex(json));
      if (items.length >= (json.meta?.count ?? 0) || !json.results?.length) break;
    }
    return items;
  },
  async datacite(orcid, fetchFn) {
    return normalizeDatacite(await getJson(`https://api.datacite.org/dois?user-id=${orcid}&page[size]=1000`, fetchFn));
  },
  async openaire(orcid, fetchFn) {
    const items = [];
    for (let page = 1; page <= MAX_PAGES; page++) {
      const json = await getJson(`https://api.openaire.eu/graph/v1/researchProducts?authorOrcid=${orcid}&pageSize=100&page=${page}`, fetchFn);
      items.push(...normalizeOpenaire(json));
      if (items.length >= (json.header?.numFound ?? 0) || !json.results?.length) break;
    }
    return items;
  },
};

// Queries every source; a failing source is reported, never fatal.
export async function collectEvidence(orcid, { sources = Object.keys(fetchers), fetchFn = globalThis.fetch.bind(globalThis), now = () => new Date().toISOString() } = {}) {
  if (!isValidOrcid(orcid)) throw new Error(`Not a valid ORCID iD: ${orcid}`);
  const results = await Promise.allSettled(sources.map((s) => fetchers[s](orcid, fetchFn)));
  const evidence = [];
  const consulted = results.map((r, i) => {
    if (r.status === "fulfilled") evidence.push(...r.value);
    return {
      source: sources[i],
      ok: r.status === "fulfilled",
      count: r.status === "fulfilled" ? r.value.length : 0,
      error: r.status === "rejected" ? String(r.reason?.message ?? r.reason) : null,
      retrieved_at: now(),
    };
  });
  return { evidence, consulted };
}
