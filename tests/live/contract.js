// Weekly contract check against the live APIs.
import { test } from "node:test";
import assert from "node:assert/strict";
import { fetchers } from "../../src/connectors.js";

const ORCID = "0000-0002-1825-0097";
const fetchFn = (url, opts) => fetch(url, { ...opts, headers: { ...opts?.headers, "User-Agent": "openresearchmetrics (live contract check)" } });

for (const source of Object.keys(fetchers)) {
  test(`live: ${source} answers with items of the expected shape`, async () => {
    const items = await fetchers[source](ORCID, fetchFn);
    assert.ok(items.length > 0);
    if (source === "openalex") assert.ok(items.every((i) => typeof i.is_oa === "boolean"), "open_access.is_oa missing");
    if (source === "datacite") assert.ok(items.some((i) => Number.isInteger(i.citations)), "citationCount missing");
    if (source === "openaire") assert.ok(items.every((i) => typeof i.access_right === "string"), "bestAccessRight missing");
  });
}
