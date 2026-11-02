# Contributing

Thank you for helping improve OpenResearchMetrics. Proposals for new indicators, better definitions and new evidence sources are welcome.

## Proposing an indicator

Open an issue with a draft card: name, family, definition, rationale, numerator, denominator, sources and limitations, plus the literature or policy reference that supports it. New or changed definitions are reviewed by the maintainer and released as a new methodology version; earlier versions stay computable.

## Running the tests

- Engine, catalog and connectors: `node --test` (Node 22 or later, no dependencies).
- Catalog against its schema: `pip install jsonschema && python tests/validate_schema.py`.
- Live API contracts (network): `node --test tests/live/contract.js`.

## Changes that may be made without the maintainer's review

- Connector code in `src/connectors.js` when an API changes shape, together with the matching recorded responses in `tests/fixtures/`.
- Documentation, the web page layout and styles.

## Changes that always need the maintainer's review

- `data/`, `schema/`, `src/engine.js` and `tests/regression/`: the indicator definitions, their procedures and expected results.
- Workflows, `.maintenance.json`, `CODEOWNERS` and this file.

Tests are never weakened or deleted to make them pass.

## Principles

- No composite score, ever.
- An indicator that cannot be verified is reported as unverifiable, never as zero.
- No dependencies in the JavaScript.
