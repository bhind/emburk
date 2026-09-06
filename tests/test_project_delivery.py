import csv
import datetime as dt
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.project_delivery import AuditError, ProjectRef, append_snapshot, csv_safe, ideal_remaining, make_snapshot, normalize_snapshot_item, render_svg, review_candidate, snapshot_items


def item(number, status, points, iteration="i1", content_type="Issue"):
    return {"content": {"number": number, "type": content_type}, "status": status, "story Points": points, "iteration": {"iterationId": iteration, "title": "2026-W36", "startDate": "2026-08-31", "duration": 7}}


class ProjectDeliveryTest(unittest.TestCase):
    def test_snapshot_item_normalizes_only_delivery_fields(self):
        node = {"type": "ISSUE", "fieldValues": {"nodes": [
            {"name": "In Progress", "field": {"name": "Status"}},
            {"number": 3, "field": {"name": "Story Points"}},
            {"iterationId": "i1", "title": "2026-W36", "startDate": "2026-08-31", "duration": 7, "field": {"name": "Iteration"}},
            {"name": "P1", "field": {"name": "Priority"}},
        ]}}
        expected = item(1, "In Progress", 3)
        del expected["content"]["number"]
        self.assertEqual(normalize_snapshot_item(node), expected)

    @patch("scripts.project_delivery.run_gh")
    def test_snapshot_items_follows_graphql_pagination(self, run_gh_mock):
        def page(node_type, has_next, cursor):
            return {"data": {"user": {"projectV2": {"items": {
                "nodes": [{"type": node_type, "fieldValues": {"nodes": []}}],
                "pageInfo": {"hasNextPage": has_next, "endCursor": cursor},
            }}}}}

        run_gh_mock.side_effect = [page("ISSUE", True, "next"), page("PULL_REQUEST", False, None)]
        project = ProjectRef("bhind", 2, "Emburk Delivery", "https://example/project")
        self.assertEqual([entry["content"]["type"] for entry in snapshot_items(project)], ["Issue", "PullRequest"])
        self.assertEqual(run_gh_mock.call_count, 2)
        self.assertIn("cursor=next", run_gh_mock.call_args.args)

    @patch("scripts.project_delivery.run_gh")
    def test_snapshot_items_fails_closed_without_pagination_cursor(self, run_gh_mock):
        run_gh_mock.return_value = {"data": {"user": {"projectV2": {"items": {
            "nodes": [], "pageInfo": {"hasNextPage": True, "endCursor": None},
        }}}}}
        with self.assertRaisesRegex(AuditError, "no end cursor"):
            snapshot_items(ProjectRef("bhind", 2, "Emburk Delivery", "https://example/project"))

    @patch("scripts.project_delivery.run_gh")
    def test_snapshot_items_fails_closed_on_repeated_cursor(self, run_gh_mock):
        repeated = {"data": {"user": {"projectV2": {"items": {
            "nodes": [], "pageInfo": {"hasNextPage": True, "endCursor": "same"},
        }}}}}
        run_gh_mock.side_effect = [repeated, repeated]
        with self.assertRaisesRegex(AuditError, "repeated an end cursor"):
            snapshot_items(ProjectRef("bhind", 2, "Emburk Delivery", "https://example/project"))
        self.assertEqual(run_gh_mock.call_count, 2)

    def test_workflow_separates_events_and_requires_credential_gate(self):
        workflow = (Path(__file__).parents[1] / ".github/workflows/project-delivery.yml").read_text(encoding="utf-8")
        self.assertIn("github.event_name == 'pull_request_target'", workflow)
        self.assertIn("github.event.pull_request.head.repo.full_name == github.repository", workflow)
        self.assertIn("github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'", workflow)
        self.assertEqual(workflow.count("needs: credential_gate"), 2)
        self.assertEqual(workflow.count("needs.credential_gate.outputs.configured == 'true'"), 2)
        self.assertNotIn("snapshot:\n    if: github.ref", workflow)
        review = workflow.split("\n  review:\n", 1)[1].split("\n  snapshot:\n", 1)[0]
        snapshot = workflow.split("\n  snapshot:\n", 1)[1]
        self.assertNotIn("github.event_name == 'schedule'", review)
        self.assertNotIn("github.event_name == 'pull_request_target'", snapshot)
        self.assertIn("secrets.EMBURK_PROJECT_TOKEN", workflow)
        self.assertNotIn("secrets.PROJECTS_TOKEN", workflow)

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

    def test_review_accepts_one_in_progress_issue(self):
        items = [{"id": "issue", "status": "In Progress", "content": {"type": "Issue", "url": "https://example/issues/1"}}]
        self.assertEqual(review_candidate(items, ["https://example/issues/1"]), "issue")

    def test_review_rejects_non_active_or_ambiguous_targets(self):
        blocked = [{"id": "issue", "status": "Blocked", "content": {"type": "Issue", "url": "https://example/issues/1"}}]
        with self.assertRaisesRegex(AuditError, "requires In Progress"):
            review_candidate(blocked, ["https://example/issues/1"])
        with self.assertRaisesRegex(AuditError, "exactly one closing Issue"):
            review_candidate(blocked, ["https://example/issues/1", "https://example/issues/2"])
        with self.assertRaisesRegex(AuditError, "exactly one Project item"):
            review_candidate([], ["https://example/issues/1"])

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
