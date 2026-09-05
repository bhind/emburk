import unittest

from scripts.project_governance_audit import (
    AuditError,
    count_wip,
    enforce_wip,
    select_project,
    validate_packet,
)


class GovernanceAuditTest(unittest.TestCase):
    def test_complete_packet_passes(self):
        body = "\n".join(
            f"## {name}\nvalue"
            for name in (
                "Authority",
                "Dependencies",
                "Branch and allowlist",
                "Artifacts",
                "Acceptance criteria",
                "Demo Command",
                "Evidence class",
                "Stop rule",
                "Non-claims",
            )
        )
        self.assertEqual(validate_packet(body), [])

    def test_missing_packet_section_is_reported(self):
        self.assertIn("Stop rule", validate_packet("## Authority\nowner"))

    def test_wip_counts_only_active_lanes(self):
        items = [
            {"status": "In Progress"},
            {"status": "Review"},
            {"status": "Blocked"},
            {"status": "Done"},
        ]
        self.assertEqual(count_wip(items), 2)
        self.assertEqual(enforce_wip(items), 2)

    def test_wip_over_limit_fails(self):
        with self.assertRaisesRegex(AuditError, "limit is 2"):
            enforce_wip([{"status": "In Progress"}] * 3)

    def test_project_discovery_requires_exactly_one_open_project(self):
        with self.assertRaisesRegex(AuditError, "found 0"):
            select_project([])
        with self.assertRaisesRegex(AuditError, "found 2"):
            select_project(
                [
                    {"owner": {"login": "a"}, "number": 1, "title": "A", "url": "u"},
                    {"owner": {"login": "a"}, "number": 2, "title": "B", "url": "v"},
                ]
            )

    def test_project_discovery_ignores_closed_project(self):
        project = select_project(
            [
                {"owner": {"login": "a"}, "number": 1, "title": "Old", "url": "u", "closed": True},
                {"owner": {"login": "a"}, "number": 2, "title": "Delivery", "url": "v", "closed": False},
            ]
        )
        self.assertEqual((project.owner, project.number), ("a", 2))


if __name__ == "__main__":
    unittest.main()
