import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


def read(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def normalized(relative_path: str) -> str:
    return " ".join(read(relative_path).split())


class QwenWorkflowPolicyTest(unittest.TestCase):
    def test_repository_contract_keeps_high_level_authority_with_codex(self) -> None:
        policy = normalized("AGENTS.md")
        for phrase in (
            "Codex and the Project Manager concentrate on task framing",
            "tools/qwen-assistant/run.py",
            "default first pass",
            "Qwen is an advisory model",
            "Its use is non-blocking",
            "Never apply its output automatically",
            "optional Qwen context allowlist",
            "docs/QWEN_ASSISTED_DEVELOPMENT.md",
        ):
            self.assertIn(phrase, policy)

    def test_project_manager_retains_decision_and_acceptance_authority(self) -> None:
        role = normalized(".codex/agents/emburk-project-manager.toml")
        for phrase in (
            "product semantics, architecture",
            "tools/qwen-assistant/run.py",
            "non-blocking",
            "default first pass",
            "separate Qwen context allowlist",
            "Qwen is advisory and has no mutation or acceptance authority",
        ):
            self.assertIn(phrase, role)

    def test_implementer_roles_share_the_bounded_assistance_contract(self) -> None:
        roles = (
            ".codex/agents/emburk-rust-core-implementer.toml",
            ".codex/agents/emburk-plugin-implementer.toml",
            ".codex/agents/emburk-compatibility-host-implementer.toml",
        )
        for path in roles:
            with self.subTest(path=path):
                role = normalized(path)
                for phrase in (
                    "tools/qwen-assistant/run.py",
                    "non-blocking default first pass",
                    "Never apply Qwen output automatically",
                    "upstream source",
                    "Qwen context allowlist",
                    "--no-project-context",
                    "independently",
                    "used, revised, or rejected",
                ):
                    self.assertIn(phrase, role)

    def test_workflow_defines_non_applying_independent_verification(self) -> None:
        workflow = normalized("docs/WORKFLOW.md")
        operating_model = normalized("docs/QWEN_ASSISTED_DEVELOPMENT.md")
        combined = workflow + operating_model
        for phrase in (
            "Qwen is advisory and non-blocking",
            "never apply it automatically",
            "Qwen's answer is not evidence",
            "Codex reviews the actual diff",
            "The Project Manager runs or confirms the task's `Demo Command`",
            "mutation allowlist grants write ownership and does not grant permission",
            "pass `--no-project-context`",
        ):
            self.assertIn(phrase, combined)

    def test_documentation_routes_readers_to_the_operating_model(self) -> None:
        development = read("docs/DEVELOPMENT.md")
        index = read("docs/README.md")
        self.assertIn("QWEN_ASSISTED_DEVELOPMENT.md", development)
        self.assertIn("QWEN_ASSISTED_DEVELOPMENT.md", index)


if __name__ == "__main__":
    unittest.main()
