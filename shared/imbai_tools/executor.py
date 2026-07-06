import os
import re
import subprocess
from pathlib import Path

BLOCKED_PATTERNS = [
    re.compile(r"\bdd\s+if=", re.IGNORECASE),
    re.compile(r"\bmkfs\b", re.IGNORECASE),
    re.compile(r"chmod\s+777", re.IGNORECASE),
    re.compile(r"curl\s+.*\|\s*bash", re.IGNORECASE),
    re.compile(r"wget\s+.*\|\s*bash", re.IGNORECASE),
    re.compile(r"curl\s+.*\|\s*sh", re.IGNORECASE),
    re.compile(r">\s*/etc/passwd", re.IGNORECASE),
    re.compile(r">\s*/etc/shadow", re.IGNORECASE),
    re.compile(r">\s*/etc/sudoers", re.IGNORECASE),
    re.compile(r":\(\)\s*\{", re.IGNORECASE),
    re.compile(r"/dev/sda\b", re.IGNORECASE),
    re.compile(r"\brm\s+-[a-zA-Z]*f[a-zA-Z]*r", re.IGNORECASE),
    re.compile(r"\brm\s+-[a-zA-Z]*r[a-zA-Z]*f", re.IGNORECASE),
    re.compile(r"\brm\s+(-[a-zA-Z]+\s+)*(/|\*/|\.\./)", re.IGNORECASE),
    re.compile(r"\bshutdown\b", re.IGNORECASE),
    re.compile(r"\breboot\b", re.IGNORECASE),
    re.compile(r"\bpoweroff\b", re.IGNORECASE),
    re.compile(r"\bhalt\b", re.IGNORECASE),
    re.compile(r"\binit\s+0\b", re.IGNORECASE),
]


class ToolError(Exception):
    pass


class ToolExecutor:
    def __init__(self, workspace: str, shell_timeout: int = 120) -> None:
        self.workspace = Path(workspace).resolve()
        self.workspace.mkdir(parents=True, exist_ok=True)
        self.shell_timeout = shell_timeout

    def resolve_path(self, path: str) -> Path:
        candidate = Path(path)
        if not candidate.is_absolute():
            candidate = self.workspace / candidate
        resolved = candidate.resolve()
        if resolved != self.workspace and self.workspace not in resolved.parents:
            raise ToolError(f"Path outside workspace: {path}")
        return resolved

    def read_file(self, path: str) -> str:
        target = self.resolve_path(path)
        if not target.is_file():
            raise ToolError(f"File not found: {path}")
        return target.read_text(encoding="utf-8", errors="replace")

    def write_file(self, path: str, content: str) -> str:
        target = self.resolve_path(path)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        return f"Wrote {len(content)} bytes to {target.relative_to(self.workspace)}"

    def list_dir(self, path: str) -> str:
        target = self.resolve_path(path or ".")
        if not target.is_dir():
            raise ToolError(f"Not a directory: {path}")
        entries = sorted(target.iterdir(), key=lambda p: p.name)
        lines = []
        for entry in entries:
            kind = "dir" if entry.is_dir() else "file"
            rel = entry.relative_to(self.workspace)
            lines.append(f"[{kind}] {rel}")
        return "\n".join(lines) if lines else "(empty directory)"

    def _validate_command(self, command: str) -> None:
        if not command or not command.strip():
            raise ToolError("Empty command")
        for pattern in BLOCKED_PATTERNS:
            if pattern.search(command):
                raise ToolError(f"Blocked command pattern: {command}")

    def run_bash(self, command: str) -> str:
        self._validate_command(command)
        env = os.environ.copy()
        env["PATH"] = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        env.setdefault("LANG", "C.UTF-8")
        result = subprocess.run(
            command,
            shell=True,
            executable="/bin/bash",
            cwd=self.workspace,
            capture_output=True,
            text=True,
            timeout=self.shell_timeout,
            env=env,
        )
        output = ""
        if result.stdout:
            output += result.stdout
        if result.stderr:
            output += ("\n" if output else "") + result.stderr
        if result.returncode != 0:
            output += f"\n[exit code {result.returncode}]"
        return output.strip() or "(no output)"

    def execute(self, name: str, arguments: dict) -> str:
        try:
            if name == "read_file":
                return self.read_file(arguments["path"])
            if name == "write_file":
                return self.write_file(arguments["path"], arguments["content"])
            if name == "list_dir":
                return self.list_dir(arguments.get("path", "."))
            if name == "run_bash":
                return self.run_bash(arguments["command"])
            raise ToolError(f"Unknown tool: {name}")
        except ToolError:
            raise
        except subprocess.TimeoutExpired:
            raise ToolError(f"Command timed out after {self.shell_timeout}s") from None
        except KeyError as exc:
            raise ToolError(f"Missing argument: {exc}") from exc
        except Exception as exc:
            raise ToolError(str(exc)) from exc
