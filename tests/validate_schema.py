"""Validate the indicator catalog against its JSON Schema (run in CI)."""

import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker

root = Path(__file__).resolve().parents[1]
schema = json.loads((root / "schema/indicators.schema.json").read_text(encoding="utf-8"))
data = json.loads((root / "data/indicators.json").read_text(encoding="utf-8"))
errors = list(Draft202012Validator(schema, format_checker=FormatChecker()).iter_errors(data))
for e in errors:
    print(f"data/indicators.json: {'/'.join(map(str, e.path))}: {e.message}")
print("checked data/indicators.json")
sys.exit(1 if errors else 0)
