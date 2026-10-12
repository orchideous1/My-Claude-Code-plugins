#!/usr/bin/env python3
"""Tests for the multi-agent session-governance hook."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
HOOK = REPO_ROOT / "hooks/session-governance.py"


SESSION_MD = """---
current_phase: {phase}
task: test session
started: 2026-10-10
updated: 2026-10-10
context:
  session_id: alpha
  plan_approved: {approved}
  last_action: initialized
  verification_result:
---

# Current session
"""

PLAN_MD = """---
title: Test plan
status: approved
phase: PLANNING
created: 2026-10-10
updated: 2026-10-10
---

# Plan
"""


class GovernanceHookTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self._git("init", "-b", "main")
        self._git("config", "user.email", "test@example.com")
        self._git("config", "user.name", "Test User")
        self._write_manifest()
        self._write_session("UNDERSTANDING", False)
        (self.root / "src").mkdir()
        (self.root / "src/app.py").write_text("VALUE = 1\n", encoding="utf-8")
        self._git("add", ".")
        self._git("commit", "-m", "initial")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _git(self, *args: str) -> str:
        result = subprocess.run(
            ["git", *args],
            cwd=self.root,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        return result.stdout.strip()

    def _write_manifest(self) -> None:
        path = self.root / ".claude/state/active-sessions.yaml"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            """schema_version: 1
updated: 2026-10-10
integration_branch: main
governance_paths:
  - .claude/**
  - CONTRIBUTING.md
sessions:
  - id: alpha
    status: planning
    branch: codex/session/alpha
    docs: .claude/state/sessions/alpha
    owned_paths:
      - src/**
    shared_paths:
      - config/shared.yaml
    validation:
      - python -m unittest
""",
            encoding="utf-8",
        )

    def _write_session(self, phase: str, approved: bool) -> None:
        docs = self.root / ".claude/state/sessions/alpha"
        docs.mkdir(parents=True, exist_ok=True)
        (docs / "session.md").write_text(
            SESSION_MD.format(phase=phase, approved=str(approved).lower()),
            encoding="utf-8",
        )
        (docs / "plan.md").write_text(PLAN_MD, encoding="utf-8")

    def _switch_session(self) -> None:
        self._git("switch", "-c", "codex/session/alpha")

    def _run(self, event: str, **payload: object) -> subprocess.CompletedProcess[str]:
        body = {
            "hook_event_name": event,
            "cwd": str(self.root),
            **payload,
        }
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = str(self.root)
        return subprocess.run(
            ["python3", str(HOOK)],
            input=json.dumps(body),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
            check=False,
        )

    def _decision(self, result: subprocess.CompletedProcess[str]) -> str | None:
        if not result.stdout.strip():
            return None
        value = json.loads(result.stdout)
        return value.get("hookSpecificOutput", {}).get("permissionDecision")

    def test_session_start_binds_branch_and_exports_id(self) -> None:
        self._switch_session()
        env_file = self.root / "session.env"
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = str(self.root)
        env["CLAUDE_ENV_FILE"] = str(env_file)
        result = subprocess.run(
            ["python3", str(HOOK)],
            input=json.dumps(
                {
                    "hook_event_name": "SessionStart",
                    "cwd": str(self.root),
                }
            ),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("alpha", json.loads(result.stdout)["systemMessage"])
        self.assertIn("CLAUDE_SESSION_ID=alpha", env_file.read_text(encoding="utf-8"))

    def test_integration_branch_blocks_production_write(self) -> None:
        result = self._run(
            "PreToolUse",
            tool_name="Edit",
            tool_input={"file_path": str(self.root / "src/app.py")},
        )
        self.assertEqual(self._decision(result), "deny")

    def test_unapproved_session_blocks_production_write(self) -> None:
        self._switch_session()
        result = self._run(
            "PreToolUse",
            tool_name="Edit",
            tool_input={"file_path": str(self.root / "src/app.py")},
        )
        self.assertEqual(self._decision(result), "deny")

    def test_approved_executing_session_allows_owned_write(self) -> None:
        self._switch_session()
        self._write_session("EXECUTING", True)
        result = self._run(
            "PreToolUse",
            tool_name="Edit",
            tool_input={"file_path": str(self.root / "src/app.py")},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIsNone(self._decision(result))

    def test_manifest_approval_field_targets_current_milestone(self) -> None:
        manifest = self.root / ".claude/state/active-sessions.yaml"
        manifest.write_text(
            manifest.read_text(encoding="utf-8").replace(
                "    docs: .claude/state/sessions/alpha\n",
                "    docs: .claude/state/sessions/alpha\n"
                "    approval_field: milestone_2_approved\n",
            ),
            encoding="utf-8",
        )
        self._git("add", str(manifest.relative_to(self.root)))
        self._git("commit", "-m", "configure milestone approval")
        self._switch_session()
        self._write_session("EXECUTING", True)
        session = self.root / ".claude/state/sessions/alpha/session.md"
        session.write_text(
            session.read_text(encoding="utf-8").replace(
                "  plan_approved: true\n",
                "  plan_approved: true\n  milestone_2_approved: false\n",
            ),
            encoding="utf-8",
        )
        denied = self._run(
            "PreToolUse",
            tool_name="Edit",
            tool_input={"file_path": str(self.root / "src/app.py")},
        )
        self.assertEqual(self._decision(denied), "deny")

        session.write_text(
            session.read_text(encoding="utf-8").replace(
                "milestone_2_approved: false", "milestone_2_approved: true"
            ),
            encoding="utf-8",
        )
        allowed = self._run(
            "PreToolUse",
            tool_name="Edit",
            tool_input={"file_path": str(self.root / "src/app.py")},
        )
        self.assertIsNone(self._decision(allowed))

    def test_cross_session_document_write_is_denied(self) -> None:
        self._switch_session()
        self._write_session("EXECUTING", True)
        result = self._run(
            "PreToolUse",
            tool_name="Edit",
            tool_input={
                "file_path": str(
                    self.root / ".claude/state/sessions/beta/plan.md"
                )
            },
        )
        self.assertEqual(self._decision(result), "deny")

    def test_existing_long_term_document_requires_incremental_edit(self) -> None:
        self._switch_session()
        self._write_session("PLANNING", False)
        result = self._run(
            "PreToolUse",
            tool_name="Write",
            tool_input={
                "file_path": str(
                    self.root / ".claude/state/sessions/alpha/plan.md"
                )
            },
        )
        self.assertEqual(self._decision(result), "deny")
        self.assertIn("整文件", json.loads(result.stdout)["systemMessage"])

    def test_bulk_delete_from_long_term_document_is_denied(self) -> None:
        self._switch_session()
        self._write_session("PLANNING", False)
        result = self._run(
            "PreToolUse",
            tool_name="Edit",
            tool_input={
                "file_path": str(
                    self.root / ".claude/state/sessions/alpha/plan.md"
                ),
                "old_string": "important plan content",
                "new_string": "",
            },
        )
        self.assertEqual(self._decision(result), "deny")

    def test_bash_redirect_to_state_document_is_denied(self) -> None:
        self._switch_session()
        self._write_session("EXECUTING", True)
        result = self._run(
            "PreToolUse",
            tool_name="Bash",
            tool_input={
                "command": "echo broken > .claude/state/sessions/alpha/plan.md"
            },
        )
        self.assertEqual(self._decision(result), "deny")

    def test_post_tool_rejects_broken_frontmatter(self) -> None:
        self._switch_session()
        plan = self.root / ".claude/state/sessions/alpha/plan.md"
        plan.write_text("# no frontmatter\n", encoding="utf-8")
        result = self._run(
            "PostToolUse",
            tool_name="Edit",
            tool_input={"file_path": str(plan)},
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("frontmatter", result.stderr)

    def test_workspace_entry_does_not_require_frontmatter(self) -> None:
        agents = self.root / "AGENTS.md"
        agents.write_text("# Workspace instructions\n", encoding="utf-8")
        result = self._run(
            "PostToolUse",
            tool_name="Edit",
            tool_input={"file_path": str(agents)},
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_existing_workspace_entry_rejects_whole_file_write(self) -> None:
        agents = self.root / "AGENTS.md"
        agents.write_text("# Workspace instructions\n", encoding="utf-8")
        result = self._run(
            "PreToolUse",
            tool_name="Write",
            tool_input={"file_path": str(agents)},
        )
        self.assertEqual(self._decision(result), "deny")
        self.assertIn("整文件", json.loads(result.stdout)["systemMessage"])

    def test_stop_blocks_code_change_without_session_update(self) -> None:
        self._switch_session()
        self._write_session("EXECUTING", True)
        self._git("add", ".claude/state/sessions/alpha/session.md")
        self._git("commit", "-m", "approve plan")
        (self.root / "src/app.py").write_text("VALUE = 2\n", encoding="utf-8")
        result = self._run("Stop")
        value = json.loads(result.stdout)
        self.assertEqual(value["decision"], "block")
        self.assertIn("session.md", value["reason"])

    def test_stop_allows_owned_change_with_session_update(self) -> None:
        self._switch_session()
        self._write_session("EXECUTING", True)
        self._git("add", ".claude/state/sessions/alpha/session.md")
        self._git("commit", "-m", "approve plan")
        (self.root / "src/app.py").write_text("VALUE = 2\n", encoding="utf-8")
        session = self.root / ".claude/state/sessions/alpha/session.md"
        session.write_text(
            session.read_text(encoding="utf-8").replace(
                "last_action: initialized", "last_action: changed app"
            ),
            encoding="utf-8",
        )
        result = self._run("Stop")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")

    def test_stop_blocks_cross_session_state_even_under_governance_glob(self) -> None:
        self._switch_session()
        self._write_session("EXECUTING", True)
        self._git("add", ".claude/state/sessions/alpha/session.md")
        self._git("commit", "-m", "approve plan")
        other = self.root / ".claude/state/sessions/beta/session.md"
        other.parent.mkdir(parents=True)
        other.write_text(
            SESSION_MD.format(phase="EXECUTING", approved="true"),
            encoding="utf-8",
        )
        current = self.root / ".claude/state/sessions/alpha/session.md"
        current.write_text(
            current.read_text(encoding="utf-8").replace(
                "last_action: initialized", "last_action: touched beta"
            ),
            encoding="utf-8",
        )
        result = self._run("Stop")
        value = json.loads(result.stdout)
        self.assertEqual(value["decision"], "block")
        self.assertIn("cross-session", value["reason"])

    def test_stop_enforces_document_rules(self) -> None:
        manifest = self.root / ".claude/state/active-sessions.yaml"
        manifest.write_text(
            manifest.read_text(encoding="utf-8").replace(
                "    validation:\n",
                "    document_rules:\n"
                "      - paths: [src/**]\n"
                "        require: [engineering.md]\n"
                "    validation:\n",
            ),
            encoding="utf-8",
        )
        self._write_session("EXECUTING", True)
        self._git("add", ".")
        self._git("commit", "-m", "configure document rule")
        self._switch_session()
        (self.root / "src/app.py").write_text("VALUE = 2\n", encoding="utf-8")
        session = self.root / ".claude/state/sessions/alpha/session.md"
        session.write_text(
            session.read_text(encoding="utf-8").replace(
                "last_action: initialized", "last_action: changed app"
            ),
            encoding="utf-8",
        )
        result = self._run("Stop")
        value = json.loads(result.stdout)
        self.assertEqual(value["decision"], "block")
        self.assertIn("engineering.md", value["reason"])


if __name__ == "__main__":
    unittest.main()
