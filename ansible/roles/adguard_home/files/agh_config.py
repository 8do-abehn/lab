"""
Surgical edits to AdGuardHome.yaml for the manage_*.py scripts (#605).

AdGuard writes values that a yaml.safe_load/safe_dump round trip can mangle
(Go durations like 30d, #430), so the scripts must never re-dump the whole
file. set_value() rewrites only the text block of one key and leaves every
other byte alone. write_config() then re-parses the result and refuses to
write unless it equals the config the caller intended, so an unexpected file
layout fails loudly instead of corrupting AdGuard's config.
"""
import re
from pathlib import Path

import yaml


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def _is_content(line: str) -> bool:
    stripped = line.strip()
    return bool(stripped) and not stripped.startswith("#")


def _block_end(lines: list[str], start: int, key_indent: int) -> int:
    """Index just past the block of the key on line `start`."""
    i = start + 1
    while i < len(lines):
        line = lines[i]
        if _is_content(line):
            indent = _indent(line)
            # A list may sit at the key's own indent ("rewrites:\n- domain:"),
            # which is how safe_dump writes it, so "- " lines stay in the block.
            if indent < key_indent:
                break
            if indent == key_indent and not line.lstrip(" ").startswith("- "):
                break
        i += 1
    # Trailing blank and comment lines belong to whatever follows.
    while i > start + 1 and not _is_content(lines[i - 1]):
        i -= 1
    return i


def _child_indent(lines: list[str], lo: int, hi: int, default: int) -> int:
    for line in lines[lo:hi]:
        if _is_content(line):
            return _indent(line)
    return default


def _find_key(lines: list[str], lo: int, hi: int, key: str, indent: int):
    pattern = re.compile(r"^" + " " * indent + re.escape(key) + r":(\s|$)")
    for i in range(lo, hi):
        if pattern.match(lines[i]):
            return i
    return None


def _render(key: str, value, indent: int) -> list[str]:
    text = yaml.safe_dump(
        {key: value}, default_flow_style=False, sort_keys=False, allow_unicode=True
    )
    pad = " " * indent
    return [pad + line for line in text.splitlines(keepends=True)]


def set_value(text: str, path: tuple[str, ...], value) -> str:
    """Return `text` with the mapping key at `path` set to `value`."""
    lines = text.splitlines(keepends=True)
    if lines and not lines[-1].endswith("\n"):
        lines[-1] += "\n"

    lo, hi, parent_indent = 0, len(lines), -2
    for depth, key in enumerate(path):
        indent = 0 if depth == 0 else _child_indent(lines, lo, hi, parent_indent + 2)
        i = _find_key(lines, lo, hi, key, indent)
        if i is None:
            # Missing key: build the rest of the path and append it as the
            # last child of the parent block.
            nested = value
            for k in reversed(path[depth + 1:]):
                nested = {k: nested}
            lines[hi:hi] = _render(key, nested, indent)
            break
        end = _block_end(lines, i, indent)
        if depth == len(path) - 1:
            lines[i:end] = _render(key, value, indent)
            break
        lo, hi, parent_indent = i + 1, end, indent
    return "".join(lines)


def write_config(config_path: Path, text: str, edits, expected: dict) -> None:
    """Apply (path, value) edits to `text` and write it, if it parses to `expected`."""
    new_text = text
    for path, value in edits:
        new_text = set_value(new_text, path, value)
    try:
        result = yaml.safe_load(new_text)
    except yaml.YAMLError:
        result = None
    if result != expected:
        raise SystemExit(
            f"refusing to write {config_path}: the surgical edit did not produce "
            "the expected config (unexpected file layout?)"
        )
    config_path.write_text(new_text)
