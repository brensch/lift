#!/usr/bin/env python3

from pathlib import Path
import re
import sys


def find_target_block_id(text: str, target_name: str) -> str:
    pattern = re.compile(
        r"(\b[A-F0-9]{24}\b) /\* " + re.escape(target_name) + r" \*/ = \{\n"
        r"\s*isa = PBXNativeTarget;",
        re.MULTILINE,
    )
    match = pattern.search(text)
    if not match:
        raise SystemExit(f"Could not find PBXNativeTarget id for {target_name}")
    return match.group(1)


def replace_target_attributes_block(text: str, target_id: str, replacement_block: str) -> str:
    pattern = re.compile(
        r"(?ms)^(\s*)" + re.escape(target_id) + r" = \{\n.*?^\1\};$"
    )
    match = pattern.search(text)
    if not match:
        raise SystemExit(f"Could not find TargetAttributes block for target id {target_id}")

    indent = match.group(1)
    block = "\n".join(indent + line if line else line for line in replacement_block.splitlines())
    return text[: match.start()] + block + text[match.end() :]


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: patch_target_capabilities.py <path-to-project.pbxproj>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    text = path.read_text()

    runner_id = find_target_block_id(text, "Runner")
    watch_id = find_target_block_id(text, "SchliftWatch")

    runner_block = f"""{runner_id} = {{
	CreatedOnToolsVersion = 7.3.1;
	LastSwiftMigration = 1100;
	ProvisioningStyle = Manual;
	SystemCapabilities = {{
		com.apple.HealthKit = {{
			enabled = 1;
		}};
		com.apple.SafariKeychain = {{
			enabled = 1;
		}};
	}};
}};"""

    watch_block = f"""{watch_id} = {{
	CreatedOnToolsVersion = 7.3.1;
	ProvisioningStyle = Manual;
	SystemCapabilities = {{
		com.apple.HealthKit = {{
			enabled = 1;
		}};
	}};
}};"""

    text = replace_target_attributes_block(text, runner_id, runner_block)
    text = replace_target_attributes_block(text, watch_id, watch_block)
    path.write_text(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
