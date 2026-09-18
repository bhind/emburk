#!/usr/bin/env python3
"""Stage-A guard: Boolean reference captures are not native differential evidence.

This file deliberately has no native execution or equality assertion.  Stage B
may add a separately reviewed native comparator after the Project Manager has
selected a policy from the recorded reference observations.
"""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("t0032_boolean_oracle", ROOT / "tools/t0032-boolean-file-csv-oracle/run.py")
oracle = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(oracle)


class StageAGuardTests(unittest.TestCase):
    def test_stage_a_has_three_reference_cases_and_no_native_binary_contract(self):
        self.assertEqual(len(oracle.CASES), 3)
        self.assertFalse(hasattr(oracle, "EMBURK_BINARY"))


if __name__ == "__main__":
    unittest.main()
