import argparse
import importlib.util
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


MODULE_PATH = (
    Path(__file__).resolve().parents[1] / "tools" / "qwen-assistant" / "run.py"
)
SPEC = importlib.util.spec_from_file_location("qwen_assistant", MODULE_PATH)
qwen_assistant = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = qwen_assistant
SPEC.loader.exec_module(qwen_assistant)


class FakeResponse:
    def __init__(self, payload):
        self.payload = json.dumps(payload).encode("utf-8")

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self, limit):
        return self.payload[:limit]


class QwenAssistantTests(unittest.TestCase):
    def test_repository_file_accepts_selection_with_line_numbers(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.rs"
            source.write_text("first\nsecond\nthird\n", encoding="utf-8")

            label, content = qwen_assistant.repository_file(
                "source.rs", start=2, end=3, root=root
            )

            self.assertEqual(label, "source.rs lines 2-3")
            self.assertEqual(content, "     2: second\n     3: third")

    def test_repository_file_blocks_private_generated_binary_and_large_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cases = {
                ".env": b"PASSWORD=not-sent",
                "target/output.txt": b"generated",
                "image.bin": b"text\0binary",
                "large.txt": b"x" * (qwen_assistant.MAX_FILE_BYTES + 1),
            }
            for name, content in cases.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(content)
                with self.subTest(name=name):
                    with self.assertRaises(qwen_assistant.AssistantError):
                        qwen_assistant.repository_file(name, root=root)

    def test_repository_file_blocks_paths_and_symlinks_outside_repository(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "repo"
            root.mkdir()
            outside = Path(directory) / "outside.txt"
            outside.write_text("outside", encoding="utf-8")
            link = root / "link.txt"
            link.symlink_to(outside)

            for path in (str(outside), "link.txt"):
                with self.subTest(path=path):
                    with self.assertRaises(qwen_assistant.AssistantError):
                        qwen_assistant.repository_file(path, root=root)

    def test_diff_path_policy_blocks_generated_and_credential_paths(self):
        for path in (
            Path("target/output.txt"),
            Path(".git/config"),
            Path(".aws/config"),
            Path("cert.pem"),
            Path("my-secrets.txt"),
        ):
            with self.subTest(path=path):
                with self.assertRaises(qwen_assistant.AssistantError):
                    qwen_assistant.validate_relative_path(path)
        qwen_assistant.validate_relative_path(Path("crates/core/src/build.rs"))
        qwen_assistant.validate_relative_path(Path(".run/Qwen.run.xml"))
        qwen_assistant.validate_relative_path(Path(".github/workflows/check.yml"))
        qwen_assistant.validate_relative_path(Path(".gitignore"))

    def test_secret_filter_redacts_tokens_and_blocks_private_keys(self):
        text = (
            "Authorization: Bearer abcdefghijklmnop\n"
            "api_key = 'qwertyuiop'\n"
            "github=ghp_abcdefghijklmnopqrstuvwxyz123456\n"
        )
        sanitized, count = qwen_assistant.sanitize_secrets(text)

        self.assertEqual(count, 3)
        self.assertNotIn("abcdefghijklmnop", sanitized)
        self.assertNotIn("qwertyuiop", sanitized)
        self.assertNotIn("ghp_", sanitized)
        with self.assertRaises(qwen_assistant.AssistantError):
            qwen_assistant.sanitize_secrets(
                "-----BEGIN OPENSSH PRIVATE KEY-----\n"
                "QUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFB\n"
                "-----END OPENSSH PRIVATE KEY-----"
            )

    def test_outbound_context_enforces_combined_limit(self):
        context = qwen_assistant.OutboundContext()
        with self.assertRaises(qwen_assistant.AssistantError):
            context.add("Too large", "x" * qwen_assistant.MAX_REQUEST_BYTES)

    def test_environment_selects_native_and_openai_endpoints(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            native = qwen_assistant.ApiConfiguration.from_environment()
        self.assertEqual(native.endpoint, "http://192.168.10.112:11435/api/chat")
        self.assertEqual(native.style, "ollama")
        self.assertEqual(native.timeout_seconds, 600)
        self.assertEqual(native.keep_alive, "30m")

        environment = {
            "EMBURK_QWEN_API_URL": "http://host:11435/v1",
            "EMBURK_QWEN_MODEL": "alternate",
            "EMBURK_QWEN_TIMEOUT_SECONDS": "42",
            "EMBURK_QWEN_KEEP_ALIVE": "5m",
            "EMBURK_QWEN_API_KEY": "dummy",
        }
        with mock.patch.dict(os.environ, environment, clear=True):
            compatible = qwen_assistant.ApiConfiguration.from_environment()
        self.assertEqual(compatible.endpoint, "http://host:11435/v1/chat/completions")
        self.assertEqual(compatible.style, "openai")
        self.assertEqual(compatible.model, "alternate")
        self.assertEqual(compatible.timeout_seconds, 42)
        self.assertEqual(compatible.keep_alive, "5m")
        self.assertEqual(compatible.api_key, "dummy")

    def test_native_client_uses_keep_alive_and_parses_message(self):
        configuration = qwen_assistant.ApiConfiguration(
            endpoint="http://host/api/chat",
            style="ollama",
            model="qwen",
            timeout_seconds=10,
            keep_alive="30m",
            api_key="ollama",
        )
        captured = {}

        def urlopen(request, timeout):
            captured["request"] = request
            captured["timeout"] = timeout
            return FakeResponse({"message": {"content": "answer"}})

        with mock.patch.object(qwen_assistant.urllib.request, "urlopen", urlopen):
            result = qwen_assistant.QwenClient(configuration).chat("question")

        payload = json.loads(captured["request"].data)
        self.assertEqual(result, "answer")
        self.assertEqual(payload["model"], "qwen")
        self.assertEqual(payload["keep_alive"], "30m")
        self.assertFalse(payload["stream"])
        self.assertEqual(captured["timeout"], 10)
        self.assertNotIn("Authorization", captured["request"].headers)

    def test_openai_client_uses_dummy_key_and_parses_choice(self):
        configuration = qwen_assistant.ApiConfiguration(
            endpoint="http://host/v1/chat/completions",
            style="openai",
            model="qwen",
            timeout_seconds=10,
            keep_alive="30m",
            api_key="ollama",
        )
        captured = {}

        def urlopen(request, timeout):
            captured["request"] = request
            return FakeResponse({"choices": [{"message": {"content": "answer"}}]})

        with mock.patch.object(qwen_assistant.urllib.request, "urlopen", urlopen):
            result = qwen_assistant.QwenClient(configuration).chat("question")

        self.assertEqual(result, "answer")
        self.assertEqual(captured["request"].get_header("Authorization"), "Bearer ollama")

    def test_fix_response_requires_and_extracts_a_unified_diff(self):
        response = "summary\ndiff --git a/a.rs b/a.rs\n--- a/a.rs\n+++ b/a.rs\n@@ -1 +1 @@\n-old\n+new\n"
        self.assertTrue(
            qwen_assistant.extract_unified_diff(response, {"a.rs"}).startswith(
                "diff --git"
            )
        )
        with self.assertRaises(qwen_assistant.AssistantError):
            qwen_assistant.extract_unified_diff("Try changing the function.")
        with self.assertRaises(qwen_assistant.AssistantError):
            qwen_assistant.extract_unified_diff(response, {"other.rs"})

    def test_parser_exposes_advisory_modes_but_no_apply_mode(self):
        parser = qwen_assistant.create_parser()
        action = next(
            action
            for action in parser._actions
            if isinstance(action, argparse._SubParsersAction)
        )
        self.assertEqual(
            set(action.choices),
            {"chat", "explain", "error", "fix", "review", "verify"},
        )
        self.assertNotIn("apply", action.choices)

    def test_verification_stops_after_first_failed_command(self):
        results = [mock.Mock(returncode=0), mock.Mock(returncode=7)]
        with mock.patch.object(
            qwen_assistant.subprocess, "run", side_effect=results
        ) as run:
            return_code = qwen_assistant.run_verification(None)

        self.assertEqual(return_code, 7)
        self.assertEqual(run.call_count, 2)


if __name__ == "__main__":
    unittest.main()
