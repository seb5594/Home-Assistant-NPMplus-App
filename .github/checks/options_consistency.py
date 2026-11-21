#!/usr/bin/env python3
"""Keeps the app options, their environment mapping and their texts in step.

An option lives in three places: the schema in config.yaml, the translation files and, when it
controls an NPMplus environment variable, option-env.map. Forgetting one of them only shows up
for users, so the pipeline checks it:

  * every option of the schema is either mapped to a variable or listed in APP_OPTIONS below,
  * every mapping points at an option that exists,
  * every option has a name and a description in every translation file,
  * the ingress port is the same in config.yaml and in the ingress module.
"""
import re
import sys
from pathlib import Path

import yaml

APP = Path("npmplus")
MAP_FILE = APP / "rootfs/usr/local/share/npmplus-app/option-env.map"
INGRESS_MODULE = APP / "rootfs/usr/local/lib/npmplus-app/ingress.sh"

# Options handled by the app's own code instead of an NPMplus environment variable.
APP_OPTIONS = {"interface.support_footer", "advanced.extra_environment", "migration.source"}


def leaf_options(schema, prefix=""):
    """Dotted paths of all options; a group (nested mapping) is not an option itself."""
    paths = []
    for key, value in schema.items():
        if isinstance(value, dict):
            paths += leaf_options(value, f"{prefix}{key}.")
        else:
            paths.append(f"{prefix}{key}")
    return paths


def mapped_options():
    entries = {}
    for line in MAP_FILE.read_text().splitlines():
        if line.strip() and not line.startswith("#"):
            path, variable = line.split("=", 1)
            entries[path] = variable
    return entries


def translated_entries(fields, prefix=""):
    """{dotted path: entry} for every option and group in a translation file."""
    entries = {}
    for key, entry in (fields or {}).items():
        entries[f"{prefix}{key}"] = entry
        entries.update(translated_entries(entry.get("fields"), f"{prefix}{key}."))
    return entries


def check_mapping(config, problems):
    options = set(leaf_options(config["schema"]))
    mapped = mapped_options()
    for path in sorted(options - set(mapped) - APP_OPTIONS):
        problems.append(f"Option {path} has no line in {MAP_FILE.name} (and is not an app option)")
    for path in sorted(set(mapped) - options):
        problems.append(f"{MAP_FILE.name} maps {path}, which is not in the schema")
    for path in sorted(APP_OPTIONS - options):
        problems.append(f"APP_OPTIONS lists {path}, which is not in the schema")
    duplicates = [name for name in set(mapped.values()) if list(mapped.values()).count(name) > 1]
    for name in sorted(duplicates):
        problems.append(f"{name} is set by more than one option")


def check_defaults(config, problems):
    for group, value in config["schema"].items():
        if isinstance(value, dict) and group not in config["options"]:
            problems.append(f"options needs a default (at least {{}}) for the group {group}: "
                            "the Supervisor rejects a missing group")


def check_translations(config, problems):
    wanted = set(leaf_options(config["schema"])) | {key for key, value in config["schema"].items()
                                                     if isinstance(value, dict)}
    for file in sorted((APP / "translations").glob("*.yaml")):
        entries = translated_entries((yaml.safe_load(file.read_text()) or {}).get("configuration"))
        for path in sorted(wanted):
            entry = entries.get(path) or {}
            if not entry.get("description"):
                problems.append(f"{file.name}: {path} needs a description")


def check_ingress_port(config, problems):
    declared = re.search(r"INGRESS_PORT=\"\$\{INGRESS_PORT:-(\d+)\}\"", INGRESS_MODULE.read_text())
    if not declared or int(declared.group(1)) != config["ingress_port"]:
        problems.append(f"The ingress port differs between config.yaml ({config['ingress_port']}) and "
                        f"{INGRESS_MODULE.name} ({declared.group(1) if declared else 'not found'})")
    if f"[PORT:{config['ingress_port']}]" not in config.get("watchdog", ""):
        problems.append("The watchdog URL must probe the ingress port")


def main():
    config = yaml.safe_load((APP / "config.yaml").read_text())
    problems = []
    check_mapping(config, problems)
    check_defaults(config, problems)
    check_translations(config, problems)
    check_ingress_port(config, problems)
    for problem in problems:
        print(f"::error::{problem}")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
