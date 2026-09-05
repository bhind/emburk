import csv
import datetime as dt
import tempfile
import unittest
from pathlib import Path

from scripts.project_delivery import AuditError, append_snapshot, csv_safe, ideal_remaining, make_snapshot, render_svg


def item(number, status, points, iteration="i1", content_type="Issue"):
    return {"content": {"number": number, "type": content_type}, "status": status, "story Points": points, "iteration": {"iterationId": iteration, "title": "2026-W36", "startDate": "2026-08-31", "duration": 7}}


class ProjectDeliveryTest(unittest.TestCase):
    def test_snapshot_counts_remaining_completion_and_status(self):
        value = make_snapshot([item(1, "In Progress", 5), item(2, "Blocked", 3), item(3, "Done", 2), item(4, "Review", 5, content_type="PullRequest")], dt.date(2026, 9, 5))
        self.assertEqual((value.total_issues, value.remaining_issues, value.remaining_points), (3, 2, 8))
        self.assertEqual((value.completed_issues, value.completed_points), (1, 2))
        self.assertEqual(value.status_counts, {"Blocked": 1, "Done": 1, "In Progress": 1})

    def test_ambiguous_current_iteration_fails(self):
        with self.assertRaisesRegex(AuditError, "found 0"):
            make_snapshot([], dt.date(2026, 9, 5))

    def test_ideal_line_reaches_zero_at_iteration_end(self):
        self.assertEqual(ideal_remaining(10, "2026-08-31", 7, "2026-08-31"), 10)
        self.assertEqual(ideal_remaining(10, "2026-08-31", 7, "2026-09-07"), 0)

    def test_csv_formula_prefix_is_neutralized(self):
        self.assertEqual(csv_safe("=HYPERLINK(1)"), "'=HYPERLINK(1)")
        self.assertEqual(csv_safe("2026-W36"), "2026-W36")

    def test_append_is_idempotent_per_day_and_svg_is_rendered(self):
        value = make_snapshot([item(1, "In Progress", 5)], dt.date(2026, 9, 5))
        with tempfile.TemporaryDirectory() as directory:
            csv_path = Path(directory) / "snapshot.csv"
            append_snapshot(csv_path, value)
            rows = append_snapshot(csv_path, value)
            self.assertEqual(len(rows), 1)
            with csv_path.open(newline="", encoding="utf-8") as handle:
                self.assertEqual(len(list(csv.DictReader(handle))), 1)
            svg_path = Path(directory) / "chart.svg"
            render_svg(rows, svg_path, "remaining_points", "Points")
            self.assertIn("ideal", svg_path.read_text(encoding="utf-8"))

    def test_append_preserves_prior_days(self):
        first = make_snapshot([item(1, "In Progress", 5)], dt.date(2026, 9, 5))
        second = make_snapshot([item(1, "Done", 5)], dt.date(2026, 9, 6))
        with tempfile.TemporaryDirectory() as directory:
            csv_path = Path(directory) / "snapshot.csv"
            append_snapshot(csv_path, first)
            rows = append_snapshot(csv_path, second)
            self.assertEqual([row["date"] for row in rows], ["2026-09-05", "2026-09-06"])
            self.assertEqual([row["remaining_points"] for row in rows], ["5.0", "0"])


if __name__ == "__main__":
    unittest.main()
