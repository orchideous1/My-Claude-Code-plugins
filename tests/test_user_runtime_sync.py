#!/usr/bin/env python3
"""Tests for user-level Claude, Codex, and Kimi Code runtime registration."""

from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SYNC = ROOT / "scripts/core/sync-user-runtimes.py"
MARKER = "<!-- structured-development-workflows:start -->"


class UserRuntimeSyncTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.home = Path(self.temp.name)

        claude = self.home / ".claude"
        claude.mkdir()
        (claude / "CLAUDE.md").write_text(
            "# Existing Claude rules\n\nKeep this text.\n", encoding="utf-8"
        )
        (claude / "settings.json").write_text(
            json.dumps(
                {
                    "env": {"SECRET": "preserve-me"},
                    "hooks": {
                        "Stop": [
                            {
                                "matcher": "*",
                                "hooks": [{"type": "command", "command": "custom-stop"}],
                            }
                        ]
                    },
                }
            ),
            encoding="utf-8",
        )

        codex = self.home / ".codex"
        codex.mkdir()
        (codex / "AGENTS.md").write_text("# Existing Codex rules\n", encoding="utf-8")
        (codex / "hooks.json").write_text(
            json.dumps(
                {
                    "hooks": {
                        "PreToolUse": [
                            {
                                "matcher": "Bash",
                                "hooks": [{"type": "command", "command": "custom-check"}],
                            }
                        ]
                    }
                }
            ),
            encoding="utf-8",
        )

        kimi_code = self.home / ".kimi-code"
        kimi_code.mkdir()
        (kimi_code / "AGENTS.md").write_text(
            "# Existing Kimi rules\n", encoding="utf-8"
        )

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _run(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["python3", str(SYNC), "--home", str(self.home)],
            cwd=ROOT,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    def test_sync_preserves_user_config_and_is_idempotent(self) -> None:
        first = self._run()
        self.assertEqual(first.returncode, 0, first.stderr)
        second = self._run()
        self.assertEqual(second.returncode, 0, second.stderr)

        for relative, prefix in (
            (".claude/CLAUDE.md", "# Existing Claude rules"),
            (".codex/AGENTS.md", "# Existing Codex rules"),
            (".kimi-code/AGENTS.md", "# Existing Kimi rules"),
        ):
            text = (self.home / relative).read_text(encoding="utf-8")
            self.assertTrue(text.startswith(prefix), relative)
            self.assertEqual(text.count(MARKER), 1, relative)

        claude_settings = json.loads(
            (self.home / ".claude/settings.json").read_text(encoding="utf-8")
        )
        self.assertEqual(claude_settings["env"]["SECRET"], "preserve-me")
        self.assertTrue(
            any("custom-stop" in json.dumps(item) for item in claude_settings["hooks"]["Stop"])
        )
        self.assertEqual(
            sum(
                "session-governance.py" in json.dumps(item)
                for entries in claude_settings["hooks"].values()
                for item in entries
            ),
            6,
        )

        codex_hooks = json.loads(
            (self.home / ".codex/hooks.json").read_text(encoding="utf-8")
        )
        self.assertTrue(
            any(
                "custom-check" in json.dumps(item)
                for item in codex_hooks["hooks"]["PreToolUse"]
            )
        )
        self.assertEqual(
            sum(
                "session-governance.py" in json.dumps(item)
                for entries in codex_hooks["hooks"].values()
                for item in entries
            ),
            6,
        )

        claude_skill = (self.home / ".claude/skills/build/SKILL.md").read_text(
            encoding="utf-8"
        )
        codex_skill = (self.home / ".codex/skills/build/SKILL.md").read_text(
            encoding="utf-8"
        )
        kimi_skill = (self.home / ".kimi-code/skills/build/SKILL.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("~/.claude/scripts", claude_skill)
        self.assertIn("/.codex/structured-development-workflows/scripts", codex_skill)
        self.assertNotIn("~/.claude/scripts", codex_skill)
        self.assertIn(
            "/.kimi-code/structured-development-workflows/scripts", kimi_skill
        )
        self.assertFalse((self.home / ".kimi").exists())


if __name__ == "__main__":
    unittest.main()
