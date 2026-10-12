#!/usr/bin/env python3
"""Claude Code and Codex hook for Git-backed session governance.

The hook is intentionally inactive unless the workspace contains
`.claude/state/active-sessions.yaml`. It uses that manifest as the machine
source of truth for branch ownership and allowed paths.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:  # pragma: no cover - exercised only on unprepared hosts
    yaml = None


MANIFEST_PATH = Path(".claude/state/active-sessions.yaml")
GLOBAL_LONG_TERM_DOCS = {
    "AGENTS.md",
    "CLAUDE.md",
    ".claude/CLAUDE.md",
    ".claude/state/development-governance.md",
    ".claude/state/git-workflow.md",
    ".claude/state/session-content-guide.md",
    ".claude/state/active-sessions.yaml",
    ".claude/state/goal-tracker.md",
    ".claude/state/architecture.md",
    "CONTRIBUTING.md",
}
SESSION_STATE_NAMES = {"session.md"}
SESSION_LONG_TERM_NAMES = {
    "plan.md",
    "algorithm.md",
    "engineering.md",
    "data-dict.md",
    "data-contracts.md",
    "architecture.md",
}
DESIGN_DOC_NAMES = SESSION_LONG_TERM_NAMES - {"plan.md", "architecture.md"}
CODE_PHASES = {"EXECUTING", "VERIFYING", "REFLECTING", "FIX"}
DESIGN_PHASES = {"PLANNING", "EXECUTING", "VERIFYING", "REFLECTING"}
MUTATING_SHELL = re.compile(
    r"(?:^|[;&|]\s*)(?:"
    r"apply_patch\b|(?:cat|echo|printf)\b[^\n]*>{1,2}|tee\b|"
    r"sed\s+-i\b|perl\s+-pi\b|"
    r"rm\b|mv\b|cp\b|install\b|truncate\b|touch\b|git\s+apply\b"
    r")"
)


@dataclass(frozen=True)
class Session:
    session_id: str
    branch: str
    docs: str
    owned_paths: tuple[str, ...]
    shared_paths: tuple[str, ...]
    status: str
    approval_field: str
    document_rules: tuple[dict[str, Any], ...]


@dataclass
class Context:
    root: Path
    manifest: dict[str, Any]
    branch: str
    integration_branch: str
    sessions: dict[str, Session]
    current: Session | None


class GovernanceError(RuntimeError):
    """Raised when project governance metadata is malformed."""


def _read_input() -> dict[str, Any]:
    raw = sys.stdin.read()
    if not raw.strip():
        return {}
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise GovernanceError(f"hook input is not valid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise GovernanceError("hook input must be a JSON object")
    return value


def _project_root(payload: dict[str, Any]) -> Path:
    candidate = (
        os.environ.get("CLAUDE_PROJECT_DIR")
        or payload.get("cwd")
        or os.getcwd()
    )
    return Path(str(candidate)).expanduser().resolve()


def _git(root: Path, *args: str, check: bool = True) -> str:
    result = subprocess.run(
        ["git", "-c", "core.quotePath=false", *args],
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if check and result.returncode != 0:
        message = result.stderr.strip() or "git command failed"
        raise GovernanceError(message)
    return result.stdout.rstrip("\n")


def _load_yaml(path: Path) -> dict[str, Any]:
    if yaml is None:
        raise GovernanceError(
            "PyYAML is required for session governance; install pyyaml in the "
            "Python environment used by Claude Code"
        )
    try:
        value = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        raise GovernanceError(f"cannot read {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise GovernanceError(f"{path} must contain a YAML mapping")
    return value


def _sessions(manifest: dict[str, Any]) -> dict[str, Session]:
    raw_sessions = manifest.get("sessions", [])
    if raw_sessions is None:
        raw_sessions = []
    if not isinstance(raw_sessions, list):
        raise GovernanceError("active-sessions.yaml: sessions must be a list")

    result: dict[str, Session] = {}
    branches: set[str] = set()
    for raw in raw_sessions:
        if not isinstance(raw, dict):
            raise GovernanceError("active-sessions.yaml: every session must be a mapping")
        session_id = str(raw.get("id", "")).strip()
        branch = str(raw.get("branch", "")).strip()
        docs = str(raw.get("docs", "")).strip()
        if not session_id or not branch or not docs:
            raise GovernanceError("every active session requires id, branch, and docs")
        if session_id in result:
            raise GovernanceError(f"duplicate active session id: {session_id}")
        if branch in branches:
            raise GovernanceError(f"duplicate active session branch: {branch}")
        expected_docs = f".claude/state/sessions/{session_id}"
        if docs != expected_docs:
            raise GovernanceError(
                f"{session_id}: docs must be {expected_docs}, got {docs}"
            )
        owned = raw.get("owned_paths", [])
        shared = raw.get("shared_paths", [])
        document_rules = raw.get("document_rules", [])
        if not isinstance(owned, list) or not isinstance(shared, list):
            raise GovernanceError(
                f"{session_id}: owned_paths and shared_paths must be lists"
            )
        if not isinstance(document_rules, list) or not all(
            isinstance(rule, dict) for rule in document_rules
        ):
            raise GovernanceError(f"{session_id}: document_rules must be a list of mappings")
        result[session_id] = Session(
            session_id=session_id,
            branch=branch,
            docs=docs,
            owned_paths=tuple(str(item) for item in owned),
            shared_paths=tuple(str(item) for item in shared),
            status=str(raw.get("status", "")).strip(),
            approval_field=str(raw.get("approval_field", "plan_approved")).strip()
            or "plan_approved",
            document_rules=tuple(document_rules),
        )
        branches.add(branch)
    return result


def _context(payload: dict[str, Any]) -> Context | None:
    root = _project_root(payload)
    manifest_file = root / MANIFEST_PATH
    if not manifest_file.is_file():
        return None
    manifest = _load_yaml(manifest_file)
    sessions = _sessions(manifest)
    branch = _git(root, "branch", "--show-current", check=False)
    integration = str(manifest.get("integration_branch", "")).strip()
    if not integration:
        integration = "main"
    current = next((item for item in sessions.values() if item.branch == branch), None)
    return Context(root, manifest, branch, integration, sessions, current)


def _relative_path(root: Path, raw: str) -> str | None:
    if not raw:
        return None
    path = Path(raw).expanduser()
    if not path.is_absolute():
        path = root / path
    try:
        return path.resolve(strict=False).relative_to(root).as_posix()
    except ValueError:
        return None


def _tool_path(ctx: Context, payload: dict[str, Any]) -> str | None:
    tool_input = payload.get("tool_input", {})
    if not isinstance(tool_input, dict):
        return None
    raw = tool_input.get("file_path") or tool_input.get("notebook_path")
    return _relative_path(ctx.root, str(raw or ""))


def _frontmatter(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise GovernanceError(f"{path}: missing YAML frontmatter")
    parts = text.split("\n---\n", 1)
    if len(parts) != 2:
        raise GovernanceError(f"{path}: unterminated YAML frontmatter")
    if yaml is None:
        raise GovernanceError("PyYAML is required to validate Markdown frontmatter")
    try:
        value = yaml.safe_load(parts[0][4:])
    except yaml.YAMLError as exc:
        raise GovernanceError(f"{path}: invalid YAML frontmatter: {exc}") from exc
    if not isinstance(value, dict):
        raise GovernanceError(f"{path}: frontmatter must be a mapping")
    return value


def _session_state(ctx: Context) -> tuple[dict[str, Any], Path] | tuple[None, None]:
    if ctx.current is None:
        return None, None
    path = ctx.root / ctx.current.docs / "session.md"
    if not path.is_file():
        return None, path
    return _frontmatter(path), path


def _phase(frontmatter: dict[str, Any] | None, session: Session | None) -> str:
    if frontmatter:
        for key in ("current_phase", "current_step", "phase", "status"):
            value = frontmatter.get(key)
            if value:
                return str(value).strip().upper().replace("-", "_")
    if session and session.status:
        return session.status.upper().replace("-", "_")
    return ""


def _approved(
    frontmatter: dict[str, Any] | None,
    session: Session | None,
    phase: str,
) -> bool:
    if not frontmatter:
        return False
    context = frontmatter.get("context", {})
    if not isinstance(context, dict):
        return False
    field = "fix_approved" if phase == "FIX" else "plan_approved"
    if session and phase != "FIX":
        field = session.approval_field
    return context.get(field) is True


def _is_session_path(path: str) -> tuple[str, str] | None:
    match = re.match(r"^\.claude/state/sessions/([^/]+)/(.+)$", path)
    if not match:
        return None
    return match.group(1), match.group(2)


def _is_protected(path: str) -> bool:
    if path in GLOBAL_LONG_TERM_DOCS:
        return True
    session_path = _is_session_path(path)
    return bool(
        session_path
        and Path(session_path[1]).name
        in (SESSION_STATE_NAMES | SESSION_LONG_TERM_NAMES)
    )


def _matches(path: str, patterns: tuple[str, ...] | list[str]) -> bool:
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)


def _allowed_patterns(ctx: Context) -> tuple[str, ...]:
    governance = ctx.manifest.get("governance_paths", [])
    if not isinstance(governance, list):
        governance = []
    patterns = [str(item) for item in governance]
    if ctx.current:
        patterns.extend(ctx.current.owned_paths)
        patterns.extend(ctx.current.shared_paths)
        patterns.append(f"{ctx.current.docs}/**")
    return tuple(patterns)


def _validate_document(root: Path, relative: str) -> list[str]:
    path = root / relative
    if not path.is_file():
        return [f"protected document does not exist: {relative}"]
    if not relative.startswith(".claude/state/"):
        return []
    try:
        data = _frontmatter(path)
    except (OSError, GovernanceError) as exc:
        return [str(exc)]

    errors: list[str] = []
    name = path.name
    if name == "session.md":
        if not any(data.get(key) for key in ("current_phase", "current_step", "status")):
            errors.append(
                f"{relative}: frontmatter requires current_phase, current_step, or status"
            )
        if not data.get("updated"):
            errors.append(f"{relative}: frontmatter requires updated")
    elif name == "goal-tracker.md":
        if "updated" not in data:
            errors.append(f"{relative}: frontmatter requires updated")
    elif name in SESSION_LONG_TERM_NAMES:
        for key in ("title", "status", "updated"):
            if key not in data:
                errors.append(f"{relative}: frontmatter requires {key}")
    elif relative.endswith(".md") and relative.startswith(".claude/state/"):
        if "updated" not in data:
            errors.append(f"{relative}: frontmatter requires updated")
    return errors


def _validate_manifest(ctx: Context) -> list[str]:
    errors: list[str] = []
    if ctx.manifest.get("schema_version") != 1:
        errors.append("active-sessions.yaml: schema_version must be 1")
    if not isinstance(ctx.manifest.get("governance_paths", []), list):
        errors.append("active-sessions.yaml: governance_paths must be a list")
    for session in ctx.sessions.values():
        docs = ctx.root / session.docs
        for name in ("session.md", "plan.md"):
            relative = f"{session.docs}/{name}"
            if not (docs / name).is_file():
                errors.append(f"{session.session_id}: missing {relative}")
            else:
                errors.extend(_validate_document(ctx.root, relative))
    return errors


def _deny(reason: str) -> int:
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": reason,
                },
                "systemMessage": reason,
            },
            ensure_ascii=False,
        )
    )
    return 0


def _block_stop(reasons: list[str]) -> int:
    reason = "会话治理检查未通过：\n- " + "\n- ".join(reasons)
    print(
        json.dumps(
            {"decision": "block", "reason": reason, "systemMessage": reason},
            ensure_ascii=False,
        )
    )
    return 0


def _session_message(ctx: Context) -> str:
    manifest_errors = _validate_manifest(ctx)
    if manifest_errors:
        return "会话治理元数据异常：\n- " + "\n- ".join(manifest_errors)
    if ctx.current:
        state, _ = _session_state(ctx)
        phase = _phase(state, ctx.current) or "未声明"
        return (
            f"当前 Git 分支绑定会话 `{ctx.current.session_id}`，阶段 `{phase}`。"
            f"先阅读 `{ctx.current.docs}/session.md`、`plan.md` 与相关算法/工程/"
            "数据契约文档；修改范围以 active-sessions.yaml 为准。"
        )
    if ctx.branch == ctx.integration_branch:
        return (
            f"当前位于集成分支 `{ctx.integration_branch}`。这里只允许注册/关闭会话、"
            "收敛全局治理文档和执行集成验证；生产代码应在已登记的会话分支修改。"
        )
    return (
        f"当前分支 `{ctx.branch or '(detached)'}` 未绑定 active-sessions.yaml 中的会话。"
        "在写入代码前切换到已登记会话分支，或先在集成分支注册新会话。"
    )


def _handle_session_context(ctx: Context, payload: dict[str, Any]) -> int:
    if ctx.current and os.environ.get("CLAUDE_ENV_FILE"):
        env_file = Path(os.environ["CLAUDE_ENV_FILE"])
        with env_file.open("a", encoding="utf-8") as handle:
            handle.write(f"export CLAUDE_SESSION_ID={ctx.current.session_id}\n")
    print(json.dumps({"systemMessage": _session_message(ctx)}, ensure_ascii=False))
    return 0


def _handle_bash_pre(ctx: Context, payload: dict[str, Any]) -> int:
    tool_input = payload.get("tool_input", {})
    command = str(tool_input.get("command", "")) if isinstance(tool_input, dict) else ""
    if not command or not MUTATING_SHELL.search(command):
        return 0
    if ".claude/state" in command or ".claude/CLAUDE.md" in command:
        return _deny(
            "长期状态文件不得通过通用 Bash 写入、删除或搬移；请使用 Write/Edit，"
            "或调用插件提供的受控状态脚本。"
        )
    state, _ = _session_state(ctx)
    phase = _phase(state, ctx.current)
    if (
        ctx.current is None
        or phase not in CODE_PHASES
        or not _approved(state, ctx.current, phase)
    ):
        return _deny(
            "检测到可能写文件的 Bash 命令，但当前会话未处于已批准的代码执行阶段。"
            "请先完成会话绑定和计划批准，文件修改优先使用 Write/Edit。"
        )
    return 0


def _handle_file_pre(ctx: Context, payload: dict[str, Any]) -> int:
    relative = _tool_path(ctx, payload)
    if relative is None:
        return 0
    tool_name = str(payload.get("tool_name", ""))
    session_path = _is_session_path(relative)

    if session_path:
        target_session, target_name = session_path
        if ctx.current is None:
            bootstrap_names = {"session.md", "plan.md"}
            is_bootstrap_doc = Path(target_name).name in bootstrap_names
            if ctx.branch != ctx.integration_branch or (
                target_session not in ctx.sessions and not is_bootstrap_doc
            ):
                return _deny(
                    f"`{relative}` 属于会话 `{target_session}`，但当前分支未绑定该会话。"
                )
        elif target_session != ctx.current.session_id:
            return _deny(
                f"禁止跨会话修改：当前是 `{ctx.current.session_id}`，目标属于 "
                f"`{target_session}`。"
            )

        basename = Path(target_name).name
        state, _ = _session_state(ctx)
        phase = _phase(state, ctx.current)
        if basename in DESIGN_DOC_NAMES and phase not in DESIGN_PHASES:
            return _deny(
                f"`{basename}` 只能在 PLANNING/EXECUTING/VERIFYING/REFLECTING "
                f"阶段修改；当前阶段为 `{phase or '未声明'}`。"
            )
        if basename in DESIGN_DOC_NAMES and phase in {"EXECUTING", "VERIFYING"}:
            if not _approved(state, ctx.current, phase):
                return _deny(
                    f"当前计划尚未标记批准，不能在 `{phase}` 阶段修改 `{basename}`。"
                )

    if relative in GLOBAL_LONG_TERM_DOCS and ctx.branch != ctx.integration_branch:
        return _deny(
            f"全局长期文档 `{relative}` 只在集成分支 `{ctx.integration_branch}` "
            "注册、收敛或关闭会话时修改。"
        )

    if _is_protected(relative) and tool_name == "Write" and (ctx.root / relative).exists():
        return _deny(
            f"已有长期状态文件 `{relative}` 禁止整文件 Write 覆盖；请使用 Edit 做最小增量修改。"
        )

    if _is_protected(relative) and tool_name in {"Edit", "NotebookEdit"}:
        tool_input = payload.get("tool_input", {})
        if isinstance(tool_input, dict):
            old = str(tool_input.get("old_string", ""))
            new = str(tool_input.get("new_string", ""))
            if old and not new:
                return _deny(
                    f"拒绝从长期状态文件 `{relative}` 删除整段内容而不提供替代文本。"
                )
            if len(old) >= 500 and len(new) * 4 < len(old):
                return _deny(
                    f"`{relative}` 的单次 Edit 删除超过 75% 内容；请拆分修改并明确迁移位置。"
                )
            if "---" in old and "---" not in new:
                return _deny(
                    f"`{relative}` 的修改会移除 YAML frontmatter 边界，已阻止。"
                )

    if ctx.current is None:
        if ctx.branch != ctx.integration_branch:
            return _deny(
                f"当前分支 `{ctx.branch or '(detached)'}` 未绑定活跃会话，不能修改 `{relative}`。"
            )
    elif not _matches(relative, _allowed_patterns(ctx)):
        return _deny(
            f"路径 `{relative}` 不属于会话 `{ctx.current.session_id}` 的 owned/shared 范围。"
        )

    if not _is_protected(relative):
        state, _ = _session_state(ctx)
        phase = _phase(state, ctx.current)
        if ctx.current is None:
            if not _matches(relative, _allowed_patterns(ctx)):
                return _deny(f"集成分支不允许修改非治理路径 `{relative}`。")
        elif phase not in CODE_PHASES or not _approved(state, ctx.current, phase):
            return _deny(
                f"生产文件写入要求会话处于 {sorted(CODE_PHASES)} 且存在已批准计划；"
                f"当前阶段 `{phase or '未声明'}`。"
            )
    return 0


def _handle_pre_tool(ctx: Context, payload: dict[str, Any]) -> int:
    manifest_errors = _validate_manifest(ctx)
    if manifest_errors:
        relative = _tool_path(ctx, payload)
        governance = ctx.manifest.get("governance_paths", [])
        repair_path = bool(
            relative
            and (
                _is_protected(relative)
                or _matches(relative, [str(item) for item in governance])
            )
        )
        if payload.get("tool_name") == "Bash" or not repair_path:
            return _deny(
                "active-sessions.yaml 校验失败，请先修复治理文档："
                + "; ".join(manifest_errors)
            )
    if payload.get("tool_name") == "Bash":
        return _handle_bash_pre(ctx, payload)
    return _handle_file_pre(ctx, payload)


def _handle_post_tool(ctx: Context, payload: dict[str, Any]) -> int:
    relative = _tool_path(ctx, payload)
    if relative is None:
        return 0
    errors: list[str] = []
    if relative == MANIFEST_PATH.as_posix():
        try:
            refreshed = _context(payload)
            if refreshed is not None:
                errors.extend(_validate_manifest(refreshed))
        except GovernanceError as exc:
            errors.append(str(exc))
    elif _is_protected(relative):
        errors.extend(_validate_document(ctx.root, relative))
    if errors:
        print(
            "写入后的会话治理校验失败：\n- " + "\n- ".join(errors),
            file=sys.stderr,
        )
        return 2
    return 0


def _changed_paths(ctx: Context) -> list[str]:
    output = _git(ctx.root, "status", "--porcelain", "--untracked-files=all")
    paths: list[str] = []
    for line in output.splitlines():
        if len(line) < 4:
            continue
        raw = line[3:]
        if " -> " in raw:
            raw = raw.split(" -> ", 1)[1]
        paths.append(raw.strip('"'))
    return sorted(set(paths))


def _handle_stop(ctx: Context, payload: dict[str, Any]) -> int:
    if payload.get("stop_hook_active") is True:
        return 0
    errors = _validate_manifest(ctx)
    changed = _changed_paths(ctx)
    if not changed:
        return _block_stop(errors) if errors else 0

    patterns = _allowed_patterns(ctx)
    for path in changed:
        if not _matches(path, patterns):
            errors.append(f"changed path has no current session/governance owner: {path}")

    if ctx.current:
        session_file = f"{ctx.current.docs}/session.md"
        state, _ = _session_state(ctx)
        phase = _phase(state, ctx.current)
        non_session_changes = [
            path
            for path in changed
            if not path.startswith(f"{ctx.current.docs}/")
        ]
        if non_session_changes and session_file not in changed:
            errors.append(
                f"code/config/test changes exist but {session_file} was not updated"
            )
        production_changes = [path for path in changed if not _is_protected(path)]
        if production_changes and (
            phase not in CODE_PHASES
            or not _approved(state, ctx.current, phase)
        ):
            errors.append(
                f"production changes exist while phase={phase or 'unset'} and no approved plan is active"
            )
        for path in changed:
            session_path = _is_session_path(path)
            if session_path and session_path[0] != ctx.current.session_id:
                errors.append(
                    f"cross-session state change: {path} belongs to {session_path[0]}"
                )
            if path in GLOBAL_LONG_TERM_DOCS:
                errors.append(
                    f"global long-term document changed outside {ctx.integration_branch}: {path}"
                )

        for rule in ctx.current.document_rules:
            rule_paths = rule.get("paths", [])
            required = rule.get("require", [])
            require_any = rule.get("require_any", [])
            if not isinstance(rule_paths, list):
                errors.append("document_rules.paths must be a list")
                continue
            if not any(_matches(path, [str(item) for item in rule_paths]) for path in changed):
                continue
            required_paths = [f"{ctx.current.docs}/{name}" for name in required]
            missing = [path for path in required_paths if path not in changed]
            if missing:
                errors.append(
                    "document rule requires updates: " + ", ".join(missing)
                )
            any_paths = [f"{ctx.current.docs}/{name}" for name in require_any]
            if any_paths and not any(path in changed for path in any_paths):
                errors.append(
                    "document rule requires at least one update: " + ", ".join(any_paths)
                )
    elif ctx.branch != ctx.integration_branch:
        errors.append(
            f"branch {ctx.branch or '(detached)'} is not bound to an active session"
        )

    for path in changed:
        if _is_protected(path) and (ctx.root / path).is_file():
            errors.extend(_validate_document(ctx.root, path))
    return _block_stop(sorted(set(errors))) if errors else 0


def _handle_session_end(ctx: Context) -> int:
    changed = _changed_paths(ctx)
    if not changed:
        return 0
    message = (
        "会话结束时工作树仍有修改。请确认已更新当前 session.md、记录验证结果，"
        "并按项目 Git 规范形成可运行检查点；不要依赖未提交工作树保存长期记忆。"
    )
    print(json.dumps({"systemMessage": message}, ensure_ascii=False))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--event",
        help="override hook_event_name for direct testing",
    )
    args = parser.parse_args()
    try:
        payload = _read_input()
        event = args.event or str(payload.get("hook_event_name", ""))
        ctx = _context(payload)
        if ctx is None:
            return 0
        if event in {"SessionStart", "PreCompact"}:
            return _handle_session_context(ctx, payload)
        if event == "PreToolUse":
            return _handle_pre_tool(ctx, payload)
        if event == "PostToolUse":
            return _handle_post_tool(ctx, payload)
        if event == "Stop":
            return _handle_stop(ctx, payload)
        if event == "SessionEnd":
            return _handle_session_end(ctx)
        return 0
    except GovernanceError as exc:
        event = args.event or ""
        if event == "PreToolUse":
            return _deny(f"会话治理 hook 无法安全判断：{exc}")
        if event == "Stop":
            return _block_stop([str(exc)])
        print(f"session governance hook failed: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
