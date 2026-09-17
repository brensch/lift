#!/usr/bin/env python3
"""Generate app/lib/gen/copy.dart from app/copy.yaml.

    python3 scripts/gen_copy.py          # write the Dart file
    python3 scripts/gen_copy.py --check  # exit 1 if it is out of date (CI)

Mapping: a YAML map becomes a Dart class with a const constructor and final
fields; a string a `String`; a list of maps a `List<...Item>` of a generated
class holding every key seen across the items; a list of strings a
`List<String>`. The whole tree is one `const copy = Copy(...)` so it costs
nothing at runtime and the compiler catches a key the code uses but the YAML
lost.
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "app" / "copy.yaml"
TARGET = ROOT / "app" / "lib" / "gen" / "copy.dart"


def pascal(parts: list[str]) -> str:
    return "".join(p[:1].upper() + p[1:] for part in parts for p in part.split("_"))


def camel(name: str) -> str:
    head, *rest = name.split("_")
    return head + "".join(p[:1].upper() + p[1:] for p in rest)


def dart_str(value) -> str:
    s = str(value)
    s = s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$").replace("\n", "\\n")
    return f"'{s}'"


class Gen:
    def __init__(self) -> None:
        self.classes: list[str] = []

    def emit_class(self, name: str, fields: list[tuple[str, str]]) -> None:
        lines = [f"class {name} {{"]
        for fname, ftype in fields:
            lines.append(f"  final {ftype} {fname};")
        lines.append(f"  const {name}({{")
        for fname, _ in fields:
            lines.append(f"    required this.{fname},")
        lines.append("  });")
        lines.append("}")
        self.classes.append("\n".join(lines))

    def value(self, node, path: list[str]) -> tuple[str, str]:
        """Returns (dart type, dart const expression)."""
        if isinstance(node, dict):
            name = pascal(["copy", *path]) if path else "Copy"
            fields, args = [], []
            for key, child in node.items():
                ctype, cexpr = self.value(child, [*path, key])
                fields.append((camel(key), ctype))
                args.append(f"{camel(key)}: {cexpr}")
            self.emit_class(name, fields)
            return name, f"{name}({', '.join(args)})"
        if isinstance(node, list):
            if all(isinstance(i, dict) for i in node) and node:
                name = pascal(["copy", *path, "item"])
                keys: list[str] = []
                for item in node:
                    for k in item:
                        if k not in keys:
                            keys.append(k)
                self.emit_class(name, [(camel(k), "String") for k in keys])
                items = ", ".join(
                    f"{name}({', '.join(f'{camel(k)}: {dart_str(item.get(k, ''))}' for k in keys)})" for item in node
                )
                return f"List<{name}>", f"[{items}]"
            return "List<String>", "[" + ", ".join(dart_str(i) for i in node) + "]"
        return "String", dart_str(node)


def render() -> str:
    data = yaml.safe_load(SOURCE.read_text(encoding="utf-8")) or {}
    gen = Gen()
    _, expr = gen.value(data, [])
    header = (
        "// GENERATED FROM app/copy.yaml BY scripts/gen_copy.py — DO NOT EDIT.\n"
        "// Edit the YAML, then run `make copy`.\n"
        "// ignore_for_file: type=lint\n\n"
    )
    body = "\n\n".join(reversed(gen.classes))  # leaves first, root last
    return f"{header}{body}\n\nconst copy = {expr};\n"


def main() -> int:
    check = "--check" in sys.argv
    out = render()
    if check:
        current = TARGET.read_text(encoding="utf-8") if TARGET.exists() else ""
        if current != out:
            print(f"{TARGET.relative_to(ROOT)} is out of date with app/copy.yaml; run `make copy`")
            return 1
        print("app copy is up to date")
        return 0
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(out, encoding="utf-8")
    print(f"wrote {TARGET.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
