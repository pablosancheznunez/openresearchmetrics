# OpenResearchMetrics

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23881633.svg)](https://doi.org/10.5281/zenodo.23881633)

Transparent open science indicators for responsible research assessment. Each indicator is reported on its own, with the evidence behind it, how it was computed and what it cannot see. **There is no composite score.**

**Use it in the browser:** <https://pablosancheznunez.com/openresearchmetrics/>. Enter an ORCID iD; the page queries OpenAlex, DataCite and the OpenAIRE Graph directly from your browser.

**Use it from R** (prototype): the package in [`r/`](r/) computes the same report from the same catalogue; its tests check it against the web tool's regression report.

```r
remotes::install_github("pablosancheznunez/openresearchmetrics", subdir = "r")
openresearchmetrics::orm_assess("0000-0002-1825-0097")
```

## Indicators (catalog 0.1.0)

| Family | Indicator | Value |
| --- | --- | --- |
| Availability | Open access share of publications | share |
| Availability | Datasets shared with a DOI | count |
| Availability | Software shared with a DOI | count |
| Accessibility | Repository copy share | share |
| Accessibility | Open access right in OpenAIRE | share |
| Reuse | Shared data and software cited | share |
| Declared reproducibility | Data and software outputs per publication | ratio |
| Methodological transparency | Preprint share | share |
| Methodological transparency | Study registrations | count |

Every indicator has a card in [`data/indicators.json`](data/indicators.json): definition, rationale, numerator, denominator, sources, limitations and methodology version. Use the catalog from any language:

```r
catalog <- jsonlite::fromJSON("https://pablosancheznunez.com/openresearchmetrics/data/indicators.json")
```

## Principles

1. Each indicator stands alone. Adding them up would hide exactly what responsible assessment needs to see (DORA, CoARA).
2. If a source does not answer, or there is nothing to count, the indicator is **unverifiable**, never zero.
3. The indicators describe open practices, not research quality, and differ legitimately across disciplines.
4. A definition never changes silently: each card is bound to the code that implements its exact methodology version, and a new definition is a new version.

## Maintenance

Maintained with [research-tools-ops](https://github.com/pablosancheznunez/research-tools-ops): weekly live checks against the APIs, automatic repair proposals, Dependabot and a monthly release when something changed. Changes to the catalog, schema, engine or expected results always need the maintainer's approval.

## Tests

```bash
node --test                    # catalog, engine, connectors, regression
node --test tests/live/contract.js    # live APIs
python tests/validate_schema.py       # needs: pip install jsonschema
```

## Citation and license

See [`CITATION.cff`](CITATION.cff). Code: MIT. Catalog (`data/`, `schema/`): CC BY 4.0.
