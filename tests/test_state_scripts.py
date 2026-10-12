#!/usr/bin/env python3
"""Tests for project governance bootstrap and session initialization scripts."""

from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP = ROOT / "scripts/core/bootstrap-governance.sh"
ENSURE_STATE = ROOT / "scripts/core/ensure-state.sh"


class StateScriptTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.project = Path(self.temp.name)
        subprocess.run(
            ["git", "init", "-b", "main"],
            cwd=self.project,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_bootstrap_creates_hierarchy_without_overwrite(self) -> None:
        first = subprocess.run(
            ["bash", str(BOOTSTRAP), str(self.project), "codex/integration"],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(first.returncode, 0, first.stderr)
        expected = [
            ".claude/CLAUDE.md",
            "AGENTS.md",
            ".kimi/AGENTS.md",
            ".kimi-code/AGENTS.md",
            ".claude/state/development-governance.md",
            ".claude/state/git-workflow.md",
            ".claude/state/session-content-guide.md",
            ".claude/state/active-sessions.yaml",
            ".claude/state/goal-tracker.md",
            ".claude/state/architecture.md",
            "CONTRIBUTING.md",
        ]
        for relative in expected:
            self.assertTrue((self.project / relative).is_file(), relative)
        manifest = (self.project / ".claude/state/active-sessions.yaml").read_text(
            encoding="utf-8"
        )
        self.assertIn("integration_branch: codex/integration", manifest)

        claude_text = (self.project / ".claude/CLAUDE.md").read_text(
            encoding="utf-8"
        )
        self.assertEqual(claude_text.count("<!-- structured-governance:start -->"), 1)

    def test_bootstrap_appends_to_existing_claude_without_replacing_it(self) -> None:
        claude_file = self.project / ".claude/CLAUDE.md"
        claude_file.parent.mkdir(parents=True)
        original = "# Existing project rules\n\nKeep every original rule.\n"
        claude_file.write_text(original, encoding="utf-8")

        first = subprocess.run(
            ["bash", str(BOOTSTRAP), str(self.project), "codex/integration"],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(first.returncode, 0, first.stderr)
        first_text = claude_file.read_text(encoding="utf-8")
        self.assertTrue(first_text.startswith(original))
        self.assertEqual(
            first_text.count("<!-- structured-governance:start -->"), 1
        )

        second = subprocess.run(
            ["bash", str(BOOTSTRAP), str(self.project), "codex/integration"],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(claude_file.read_text(encoding="utf-8"), first_text)

    def test_major_build_creates_layered_session_documents(self) -> None:
        state_dir = self.project / ".claude/state"
        result = subprocess.run(
            [
                "bash",
                str(ENSURE_STATE),
                "build",
                str(state_dir),
                "alpha",
                "major",
            ],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        docs = state_dir / "sessions/alpha"
        for name in (
            "session.md",
            "plan.md",
            "algorithm.md",
            "engineering.md",
            "data-dict.md",
        ):
            self.assertTrue((docs / name).is_file(), name)
        self.assertIn(
            "current_phase: UNDERSTANDING",
            (docs / "session.md").read_text(encoding="utf-8"),
        )

    def test_invalid_existing_session_is_not_overwritten(self) -> None:
        session = self.project / ".claude/state/sessions/alpha/session.md"
        session.parent.mkdir(parents=True)
        session.write_text("important content without frontmatter\n", encoding="utf-8")
        result = subprocess.run(
            [
                "bash",
                str(ENSURE_STATE),
                "build",
                str(self.project / ".claude/state"),
                "alpha",
            ],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("拒绝自动覆盖", result.stderr)
        self.assertEqual(
            session.read_text(encoding="utf-8"),
            "important content without frontmatter\n",
        )


if __name__ == "__main__":
    unittest.main()
