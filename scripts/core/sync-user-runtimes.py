#!/usr/bin/env python3
"""Install this repository's workflows into user-level agent directories.

Usage:
    scripts/core/sync-user-runtimes.py [--home HOME] [--plugin-root ROOT]

The installer preserves existing instruction text and unrelated JSON settings.
It owns only marked instruction blocks, workflow skill directories, its runtime
directory, and hook entries that invoke session-governance.py.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import tempfile
from pathlib import Path
from typing import Any


SKILLS = ("arch", "build", "read", "summarize")
TEXT_SUFFIXES = {".md", ".sh", ".py", ".json", ".yaml", ".yml"}
MANAGED_HOOK_NAME = "session-governance.py"


class SyncError(RuntimeError):
    """Raised when an existing user configuration cannot be merged safely."""


def copy_tree(source: Path, target: Path) -> None:
    target.mkdir(parents=True, exist_ok=True)
    for source_path in source.iterdir():
        if source_path.name == "__pycache__" or source_path.suffix == ".pyc":
            continue
        target_path = target / source_path.name
        if source_path.is_dir():
            copy_tree(source_path, target_path)
        else:
            shutil.copy2(source_path, target_path)


def adapt_tree(target: Path, replacements: dict[str, str]) -> None:
    for path in target.rglob("*"):
        if not path.is_file() or path.suffix not in TEXT_SUFFIXES:
            continue
        text = path.read_text(encoding="utf-8")
        updated = text
        for old, new in replacements.items():
            updated = updated.replace(old, new)
        if updated != text:
            path.write_text(updated, encoding="utf-8")


def copy_skills(plugin_root: Path, target: Path, replacements: dict[str, str]) -> None:
    target.mkdir(parents=True, exist_ok=True)
    for name in SKILLS:
        destination = target / name
        copy_tree(plugin_root / "skills" / name, destination)
        adapt_tree(destination, replacements)


def update_managed_block(target: Path, block: str) -> None:
    lines = block.strip().splitlines()
    if len(lines) < 2 or not lines[0].startswith("<!-- "):
        raise SyncError("managed instruction block is missing boundary markers")
    start = lines[0]
    end = lines[-1]
    if not end.startswith("<!-- "):
        raise SyncError("managed instruction block is missing an end marker")

    target.parent.mkdir(parents=True, exist_ok=True)
    original = target.read_text(encoding="utf-8") if target.exists() else ""
    start_at = original.find(start)
    if start_at >= 0:
        end_at = original.find(end, start_at)
        if end_at < 0:
            raise SyncError(f"{target}: managed block has no closing marker")
        end_at += len(end)
        updated = original[:start_at] + block.strip() + original[end_at:]
    else:
        separator = "" if not original else ("\n" if original.endswith("\n") else "\n\n")
        updated = original + separator + block.strip() + "\n"
    if updated != original:
        target.write_text(updated, encoding="utf-8")


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SyncError(f"cannot safely merge {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise SyncError(f"cannot safely merge {path}: root must be a JSON object")
    return value


def write_json_atomic(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o600
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(value, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def invokes_governance(value: Any) -> bool:
    if isinstance(value, dict):
        return any(invokes_governance(item) for item in value.values())
    if isinstance(value, list):
        return any(invokes_governance(item) for item in value)
    return isinstance(value, str) and MANAGED_HOOK_NAME in value


def merge_hooks(target: Path, desired: dict[str, Any], include_description: bool) -> None:
    existing = read_json(target)
    hooks = existing.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise SyncError(f"cannot safely merge {target}: hooks must be an object")

    desired_hooks = desired.get("hooks", {})
    if not isinstance(desired_hooks, dict):
        raise SyncError("source hooks.json has an invalid hooks object")
    for event, registrations in desired_hooks.items():
        current = hooks.get(event, [])
        if not isinstance(current, list) or not isinstance(registrations, list):
            raise SyncError(f"cannot safely merge {target}: {event} must be a list")
        hooks[event] = [item for item in current if not invokes_governance(item)] + registrations

    if include_description and desired.get("description"):
        existing.setdefault("description", desired["description"])
    write_json_atomic(target, existing)


def rendered_hooks(source: Path, runtime_root: Path) -> dict[str, Any]:
    text = source.read_text(encoding="utf-8").replace(
        "${CLAUDE_PLUGIN_ROOT}", runtime_root.as_posix()
    )
    value = json.loads(text)
    if not isinstance(value, dict):
        raise SyncError("source hooks.json root must be an object")
    return value


def runtime_replacements(runtime_root: Path) -> dict[str, str]:
    prefix = runtime_root.as_posix()
    return {
        "~/.claude/scripts": f"{prefix}/scripts",
        "~/.claude/hooks": f"{prefix}/hooks",
        "~/.claude/prompt-templates": f"{prefix}/prompt-templates",
    }


def install_runtime(plugin_root: Path, runtime_root: Path) -> None:
    for name in ("scripts", "hooks", "prompt-templates"):
        copy_tree(plugin_root / name, runtime_root / name)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--home", type=Path, default=Path.home())
    parser.add_argument("--plugin-root", type=Path)
    args = parser.parse_args()

    plugin_root = (
        args.plugin_root.expanduser().resolve()
        if args.plugin_root
        else Path(__file__).resolve().parents[2]
    )
    home = args.home.expanduser().resolve()
    templates = plugin_root / "prompt-templates/user"

    claude_root = home / ".claude"
    for name in ("scripts", "hooks", "prompt-templates"):
        copy_tree(plugin_root / name, claude_root / name)
    copy_skills(plugin_root, claude_root / "skills", {})
    update_managed_block(
        claude_root / "CLAUDE.md",
        (templates / "CLAUDE_registration.md").read_text(encoding="utf-8"),
    )
    merge_hooks(
        claude_root / "settings.json",
        rendered_hooks(plugin_root / "hooks/hooks.json", claude_root),
        include_description=False,
    )

    codex_root = home / ".codex"
    codex_runtime = codex_root / "structured-development-workflows"
    install_runtime(plugin_root, codex_runtime)
    copy_skills(
        plugin_root,
        codex_root / "skills",
        runtime_replacements(codex_runtime),
    )
    update_managed_block(
        codex_root / "AGENTS.md",
        (templates / "CODEX_registration.md").read_text(encoding="utf-8"),
    )
    merge_hooks(
        codex_root / "hooks.json",
        rendered_hooks(plugin_root / "hooks/hooks.json", codex_runtime),
        include_description=True,
    )

    kimi_code_root = home / ".kimi-code"
    kimi_code_runtime = kimi_code_root / "structured-development-workflows"
    install_runtime(plugin_root, kimi_code_runtime)
    copy_skills(
        plugin_root,
        kimi_code_root / "skills",
        runtime_replacements(kimi_code_runtime),
    )
    update_managed_block(
        kimi_code_root / "AGENTS.md",
        (templates / "KIMI_CODE_registration.md").read_text(encoding="utf-8"),
    )

    print(f"Claude runtime: {claude_root}")
    print(f"Codex runtime: {codex_root}")
    print(f"Kimi Code runtime: {kimi_code_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
