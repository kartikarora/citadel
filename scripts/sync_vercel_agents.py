#!/usr/bin/env python3
"""
One-way sync script: compares Citadel's AgentRegistry.swift against
vercel-labs/skills (src/agents.ts) and adds any agents missing from Citadel.

Citadel-only entries (e.g., .matilda, .android-studio) are always preserved and
never contributed back upstream.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

VERCEL_AGENTS_URL = (
    "https://raw.githubusercontent.com/vercel-labs/skills/main/src/agents.ts"
)
DEFAULT_REGISTRY_PATH = Path("Sources/CitadelCore/AgentRegistry.swift")


@dataclass
class ParsedAgent:
    id: str
    display_name: str
    source_kind: str
    skills_dir: str
    global_skills_base: Optional[str]
    detect_bases: list[str]

    def to_swift(self) -> str:
        detect_str = ", ".join(self.detect_bases)
        global_str = self.global_skills_base if self.global_skills_base else "nil"
        return (
            f'            AgentConfig(id: "{swift_escape(self.id)}", '
            f'displayName: "{swift_escape(self.display_name)}", '
            f'sourceKind: "{swift_escape(self.source_kind)}", '
            f'skillsDir: "{swift_escape(self.skills_dir)}", '
            f"globalSkillsBase: {global_str}, "
            f"detectBases: [{detect_str}])"
        )


def swift_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def fetch_vercel_agents_ts(input_path: Optional[str]) -> str:
    if input_path:
        return Path(input_path).read_text(encoding="utf-8")
    req = urllib.request.Request(
        VERCEL_AGENTS_URL,
        headers={"User-Agent": "Citadel-AgentRegistry-Sync/1.0"},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8")


def parse_env_home_vars(ts_text: str) -> dict[str, tuple[str, str]]:
    """
    Parses top-level constants like:
      const codexHome = process.env.CODEX_HOME?.trim() || join(home, '.codex');
    Returns {var_name: (env_var, default_subpath)}.
    """
    env_vars: dict[str, tuple[str, str]] = {}
    pattern = re.compile(
        r"const\s+(\w+)\s*=\s*process\.env\.([A-Z0-9_]+)(?:\?\s*\.trim\(\))?\s*\|\|\s*join\(\s*home\s*,\s*['\"]([^'\"]+)['\"]\s*\)",
        re.MULTILINE,
    )
    for match in pattern.finditer(ts_text):
        var_name, env_name, default_subpath = match.groups()
        env_vars[var_name] = (env_name, default_subpath)

    # Also handle multi-line reasonix-style ternary fallback to join(home, '.foo')
    multiline_pattern = re.compile(
        r"const\s+(\w+)\s*=\s*process\.env\.([A-Z0-9_]+)\?\.trim\(\)\s*\|\|[\s\S]{0,220}?:\s*join\(\s*home\s*,\s*['\"]([^'\"]+)['\"]\s*\)",
        re.MULTILINE,
    )
    for match in multiline_pattern.finditer(ts_text):
        var_name, env_name, default_subpath = match.groups()
        env_vars.setdefault(var_name, (env_name, default_subpath))

    return env_vars


def find_matching_brace(text: str, brace_start: int) -> int:
    """Finds the matching '}' for '{' at brace_start, ignoring comments and string literals."""
    depth = 0
    in_single = False
    in_double = False
    in_template = False
    escaped = False
    pos = brace_start
    n = len(text)

    while pos < n:
        ch = text[pos]
        if escaped:
            escaped = False
            pos += 1
            continue
        if in_single or in_double or in_template:
            if ch == "\\":
                escaped = True
            elif in_single and ch == "'":
                in_single = False
            elif in_double and ch == '"':
                in_double = False
            elif in_template and ch == "`":
                in_template = False
            pos += 1
            continue

        if text[pos : pos + 2] == "//":
            nl = text.find("\n", pos + 2)
            pos = n if nl == -1 else nl + 1
            continue
        if text[pos : pos + 2] == "/*":
            end = text.find("*/", pos + 2)
            pos = n if end == -1 else end + 2
            continue

        if ch == "'":
            in_single = True
        elif ch == '"':
            in_double = True
        elif ch == "`":
            in_template = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return pos
        pos += 1

    raise ValueError("Unterminated '{' block in TypeScript source")


def extract_agents_object_body(ts_text: str) -> str:
    marker = "export const agents"
    idx = ts_text.find(marker)
    if idx == -1:
        raise ValueError("Could not find 'export const agents' in TypeScript source")
    eq_idx = ts_text.find("=", idx)
    brace_start = ts_text.find("{", eq_idx)
    if brace_start == -1:
        raise ValueError("Could not find opening '{' for agents object")
    brace_end = find_matching_brace(ts_text, brace_start)
    return ts_text[brace_start + 1 : brace_end]


def split_top_level_entries(body: str) -> list[tuple[str, str]]:
    """Splits top-level `key: { ... }` entries inside the agents object."""
    entries: list[tuple[str, str]] = []
    pos = 0
    n = len(body)

    while pos < n:
        while pos < n and body[pos] in " \t\r\n,":
            pos += 1
        if pos >= n:
            break
        if body[pos : pos + 2] == "//":
            nl = body.find("\n", pos)
            pos = n if nl == -1 else nl + 1
            continue
        if body[pos : pos + 2] == "/*":
            end = body.find("*/", pos + 2)
            pos = n if end == -1 else end + 2
            continue

        key_match = re.match(r"(?:['\"]([^'\"]+)['\"]|([a-zA-Z0-9_-]+))\s*:\s*\{", body[pos:])
        if not key_match:
            pos += 1
            continue

        key = key_match.group(1) or key_match.group(2)
        brace_start = pos + key_match.end() - 1
        end_pos = find_matching_brace(body, brace_start)
        entries.append((key, body[brace_start + 1 : end_pos]))
        pos = end_pos + 1

    return entries


def join_args_to_swift_base(
    base_var: str,
    parts: list[str],
    env_vars: dict[str, tuple[str, str]],
    strip_trailing_skills: bool = False,
) -> Optional[str]:
    clean_parts = [p.strip().strip("'\"") for p in parts if p.strip()]
    if strip_trailing_skills:
        if clean_parts and clean_parts[-1] == "skills":
            clean_parts = clean_parts[:-1]
        elif clean_parts and clean_parts[-1].endswith("/skills"):
            trimmed = clean_parts[-1][:-7]
            if trimmed:
                clean_parts[-1] = trimmed
            else:
                clean_parts = clean_parts[:-1]

    joined = "/".join(p.strip("/") for p in clean_parts if p.strip("/"))

    if base_var == "home":
        if not joined:
            return None
        return f'.home("{swift_escape(joined)}")'
    if base_var == "configHome":
        if not joined:
            return '.xdgConfig("")'
        return f'.xdgConfig("{swift_escape(joined)}")'
    if base_var in env_vars:
        env_name, default_subpath = env_vars[base_var]
        full_default = f"{default_subpath}/{joined}" if joined else default_subpath
        return f'.envOrHome(envVar: "{swift_escape(env_name)}", defaultSubpath: "{swift_escape(full_default)}")'
    return None


def parse_join_calls(
    expr: str,
    env_vars: dict[str, tuple[str, str]],
    strip_trailing_skills: bool = False,
) -> list[str]:
    results: list[str] = []
    for match in re.finditer(r"join\(\s*([a-zA-Z_]\w*)\s*(?:,\s*([^)]+))?\)", expr):
        base_var = match.group(1)
        raw_rest = match.group(2) or ""
        parts = re.findall(r"['\"]([^'\"]+)['\"]", raw_rest)
        base = join_args_to_swift_base(
            base_var, parts, env_vars, strip_trailing_skills=strip_trailing_skills
        )
        if base and base not in results:
            results.append(base)
    return results


def parse_vercel_agents(ts_text: str) -> list[ParsedAgent]:
    env_vars = parse_env_home_vars(ts_text)
    body = extract_agents_object_body(ts_text)
    raw_entries = split_top_level_entries(body)

    parsed: list[ParsedAgent] = []
    for key, block in raw_entries:
        name_m = re.search(r"\bname\s*:\s*['\"]([^'\"]+)['\"]", block)
        display_m = re.search(r"\bdisplayName\s*:\s*['\"]([^'\"]+)['\"]", block)
        skills_m = re.search(r"\bskillsDir\s*:\s*['\"]([^'\"]+)['\"]", block)

        agent_id = name_m.group(1) if name_m else key
        display_name = display_m.group(1) if display_m else agent_id
        skills_dir = skills_m.group(1) if skills_m else ".agents/skills"

        global_skills_base: Optional[str] = None
        global_m = re.search(r"\bglobalSkillsDir\s*:\s*([^\n,]+)", block)
        if global_m:
            global_expr = global_m.group(1).strip()
            if global_expr != "undefined":
                bases = parse_join_calls(global_expr, env_vars, strip_trailing_skills=True)
                if bases:
                    global_skills_base = bases[0]

        detect_bases: list[str] = []
        detect_idx = block.find("detectInstalled")
        if detect_idx != -1:
            detect_block = block[detect_idx:]
            detect_bases = parse_join_calls(detect_block, env_vars, strip_trailing_skills=False)
            for var_name in env_vars:
                if re.search(rf"existsSync\(\s*{re.escape(var_name)}\s*\)", detect_block):
                    env_name, default_subpath = env_vars[var_name]
                    base = f'.envOrHome(envVar: "{swift_escape(env_name)}", defaultSubpath: "{swift_escape(default_subpath)}")'
                    if base not in detect_bases:
                        detect_bases.append(base)

        if not detect_bases and global_skills_base:
            detect_bases = [global_skills_base]

        parsed.append(
            ParsedAgent(
                id=agent_id,
                display_name=display_name,
                source_kind=agent_id,
                skills_dir=skills_dir,
                global_skills_base=global_skills_base,
                detect_bases=detect_bases,
            )
        )

    return parsed


def extract_citadel_agent_ids(registry_text: str) -> set[str]:
    return set(re.findall(r'AgentConfig\(\s*id:\s*"([^"]+)"', registry_text))


def insert_missing_agents(registry_text: str, missing: list[ParsedAgent]) -> str:
    anchor = '            AgentConfig(id: "universal",'
    insert_idx = registry_text.find(anchor)
    if insert_idx == -1:
        raise ValueError("Could not find 'universal' anchor in AgentRegistry.swift")

    # Ensure the line right before anchor ends with a comma
    before = registry_text[:insert_idx].rstrip()
    if not before.endswith(","):
        before += ","

    new_lines = "\n".join(agent.to_swift() + "," for agent in missing)
    after = registry_text[insert_idx:]
    return f"{before}\n{new_lines}\n{after}"


def write_github_output(
    output_path: Optional[str],
    has_changes: bool,
    missing: list[ParsedAgent],
) -> None:
    target = output_path or os.environ.get("GITHUB_OUTPUT")
    if not target:
        return
    ids = ", ".join(a.id for a in missing)
    with open(target, "a", encoding="utf-8") as fh:
        fh.write(f"has_changes={'true' if has_changes else 'false'}\n")
        fh.write(f"missing_count={len(missing)}\n")
        fh.write(f"missing_ids={ids}\n")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Sync missing agent entries from vercel-labs/skills into Citadel's AgentRegistry.swift."
    )
    parser.add_argument(
        "--input",
        help="Optional local path to vercel agents.ts instead of fetching from GitHub.",
    )
    parser.add_argument(
        "--registry",
        default=str(DEFAULT_REGISTRY_PATH),
        help="Path to Citadel's AgentRegistry.swift.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Dry-run: report missing agents without modifying AgentRegistry.swift.",
    )
    parser.add_argument(
        "--github-output",
        help="Optional path to GitHub Actions output file.",
    )
    args = parser.parse_args()

    registry_path = Path(args.registry)
    registry_text = registry_path.read_text(encoding="utf-8")
    citadel_ids = extract_citadel_agent_ids(registry_text)

    ts_text = fetch_vercel_agents_ts(args.input)
    vercel_agents = parse_vercel_agents(ts_text)

    # Strictly one-way: only add Vercel entries missing from Citadel.
    missing = [agent for agent in vercel_agents if agent.id not in citadel_ids]

    if not missing:
        print(
            f"AgentRegistry is up to date ({len(vercel_agents)} Vercel agents checked, "
            f"{len(citadel_ids)} Citadel agents configured)."
        )
        write_github_output(args.github_output, has_changes=False, missing=[])
        return 0

    print(f"Found {len(missing)} agent(s) missing from Citadel:")
    for agent in missing:
        print(f"  + {agent.id} ({agent.display_name}) -> {agent.skills_dir}")

    if not args.check:
        updated = insert_missing_agents(registry_text, missing)
        registry_path.write_text(updated, encoding="utf-8")
        print(f"Updated {registry_path} with {len(missing)} new agent(s).")

    write_github_output(args.github_output, has_changes=True, missing=missing)
    return 0


if __name__ == "__main__":
    sys.exit(main())
