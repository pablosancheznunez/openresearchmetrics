# Maintenance instructions for AI agents

This repository is maintained partly by automated agents (see
pablosancheznunez/research-tools-ops). Follow these rules.

## Test commands

- `node --test` must pass. Node 22 or later (CI uses 24), no dependencies.
- `python tests/validate_schema.py` (needs `pip install jsonschema`).

## What you may change on your own

- Connector code in `src/connectors.js` when an API changed shape, plus the matching recorded responses in `tests/fixtures/`.
- Documentation, the web page layout and styles.

## What you must never change

- `data/`, `schema/`, `src/engine.js` and `tests/regression/`: the indicator definitions, their procedures and expected results. Propose changes in an issue instead.
- Workflows, `.maintenance.json`, `CODEOWNERS` and this file.
- Never weaken or delete a test to make it pass.

## Principles

- No composite score, ever.
- An indicator that cannot be verified is reported as unverifiable, never as zero.
- No dependencies in the JavaScript.
