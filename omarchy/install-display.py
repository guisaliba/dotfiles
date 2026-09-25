#!/usr/bin/env python3
"""Install the locally cloned Display widget without touching Omarchy packages."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "lib"))
from dotfiles_installer import (  # noqa: E402
    atomic_write_bytes, backup_regular_file, backup_tree, guard_target,
)

SOURCE = ROOT / "omarchy/display-plugin"
TARGET = Path.home() / ".config/omarchy/plugins/guisaliba.monitor"
CONFIG = Path.home() / ".config/omarchy/shell.json"
NATIVE = Path("/usr/share/omarchy/shell/plugins/panels/monitor")
SIGNATURE = ROOT / "omarchy/display-upstream.sha256"
IDENTITY = "guisaliba.monitor"
MARKER = ".dotfiles-display"
RECEIPT = ".dotfiles-display-receipt.json"


def fail(message):
    raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def native_contract():
    native, signature = NATIVE, SIGNATURE
    if os.environ.get("DOTFILES_TEST_MODE") == "1":
        native = Path(os.environ.get("DOTFILES_DISPLAY_NATIVE_DIR", native))
        signature = Path(os.environ.get("DOTFILES_DISPLAY_SIGNATURES", signature))
    for row in signature.read_text().splitlines():
        expected, name = row.split("  ", 1)
        path = native / name
        if not path.is_file() or path.is_symlink() or digest(path.read_bytes()) != expected:
            fail(f"native Display contract differs: {path}; review the Omarchy update before activation")


def paths():
    return {str(p.relative_to(SOURCE)): digest(p.read_bytes())
            for p in SOURCE.rglob("*") if p.is_file() and not p.is_symlink()}


def configuration(deactivate=False):
    guard_target(CONFIG, "Omarchy shell configuration", "file")
    if not CONFIG.is_file():
        fail(f"Omarchy shell configuration is missing: {CONFIG}")
    data = CONFIG.read_bytes()
    config = json.loads(data)
    if not isinstance(config, dict) or not isinstance(config.get("bar"), dict) or not isinstance(config["bar"].get("layout"), dict):
        fail("Omarchy bar configuration is invalid")
    existing = []
    for section in ("left", "center", "right"):
        rows = config["bar"]["layout"].get(section, [])
        if not isinstance(rows, list):
            fail(f"Omarchy bar section {section} is invalid")
        for index, entry in enumerate(rows):
            if isinstance(entry, dict) and entry.get("id") in ("omarchy.monitor", IDENTITY):
                existing.append((section, index))
    if len(existing) != 1:
        fail("expected exactly one native or enhanced Display entry in the bar")
    section, index = existing[0]
    desired = "omarchy.monitor" if deactivate else IDENTITY
    changed = config["bar"]["layout"][section][index]["id"] != desired
    config["bar"]["layout"][section][index]["id"] = desired
    return data, config, changed


def inspect_target(expected):
    guard_target(TARGET, "Display plugin target", "dir")
    if not TARGET.exists():
        return True
    if not TARGET.is_dir() or (TARGET / MARKER).is_symlink() or not (TARGET / MARKER).is_file() or (TARGET / MARKER).read_bytes() != (SOURCE / MARKER).read_bytes():
        fail(f"refusing to replace unmanaged Display plugin: {TARGET}")
    receipt = TARGET / RECEIPT
    if not receipt.is_file() or receipt.is_symlink():
        fail("Display plugin receipt is missing; preserve local edits")
    installed = json.loads(receipt.read_text())
    previous = installed.get("files")
    present = {str(p.relative_to(TARGET)): digest(p.read_bytes())
               for p in TARGET.rglob("*") if p.is_file() and not p.is_symlink() and p != receipt}
    if not isinstance(previous, dict) or present != previous or any(p.is_symlink() for p in TARGET.rglob("*")):
        fail("Display plugin has local changes; preserve them before reinstalling")
    return previous != expected


def backup_root():
    parent = Path.home() / ".local/state/dotfiles/backups"
    parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    return Path(tempfile.mkdtemp(prefix=time.strftime("%Y%m%dT%H%M%SZ-display-", time.gmtime()), dir=parent))


def install(expected, config_data, config_obj, target_changed, config_changed):
    if not target_changed and not config_changed:
        print("Display enhancement already installed")
        return
    backup = backup_root() if TARGET.exists() or config_changed else None
    if backup:
        if TARGET.exists() and target_changed:
            backup_tree(TARGET, backup, "omarchy-display", "replace-tree")
        if config_changed:
            backup_regular_file(CONFIG, backup, "omarchy-display", "activate-widget")
        print(f"Backup directory: {backup}")
    if target_changed:
        TARGET.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
        stage = Path(tempfile.mkdtemp(prefix=".dotfiles-display-", dir=TARGET.parent))
        try:
            shutil.copytree(SOURCE, stage, dirs_exist_ok=True)
            (stage / RECEIPT).write_text(json.dumps({"files": expected}, sort_keys=True) + "\n")
            if TARGET.exists():
                previous = TARGET.parent / (".dotfiles-display-old-" + os.urandom(4).hex())
                os.replace(TARGET, previous)
                try:
                    os.replace(stage, TARGET)
                except BaseException:
                    os.replace(previous, TARGET)
                    raise
                shutil.rmtree(previous)
            else:
                os.replace(stage, TARGET)
        finally:
            if stage.exists():
                shutil.rmtree(stage)
    if config_changed:
        if CONFIG.read_bytes() != config_data:
            fail("Omarchy shell.json changed during install; activation refused")
        atomic_write_bytes(CONFIG, (json.dumps(config_obj, indent=2, ensure_ascii=False) + "\n").encode(), CONFIG.stat().st_mode & 0o777)
    print(f"Display enhancement installed: {TARGET}")


def restore_native():
    """On an incompatible installed contract, leave the built-in widget active."""
    if not TARGET.is_dir() or (TARGET / MARKER).is_symlink() or not (TARGET / MARKER).is_file() or (TARGET / MARKER).read_bytes() != (SOURCE / MARKER).read_bytes():
        return
    data, config, changed = configuration(deactivate=True)
    if not changed:
        return
    backup = backup_root()
    backup_regular_file(CONFIG, backup, "omarchy-display", "deactivate-incompatible")
    if CONFIG.read_bytes() != data:
        fail("shell.json changed while returning to native Display")
    atomic_write_bytes(CONFIG, (json.dumps(config, indent=2, ensure_ascii=False) + "\n").encode(), CONFIG.stat().st_mode & 0o777)
    print(f"Native Display restored; backup: {backup}", file=sys.stderr)


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("check", "apply"):
        fail("usage: install-display.py check|apply")
    try:
        native_contract()
    except ValueError:
        if sys.argv[1] == "apply":
            restore_native()
        raise
    data, config, config_changed = configuration()
    expected = paths()
    target_changed = inspect_target(expected)
    if sys.argv[1] == "check":
        print(f"Display plugin: {TARGET}; {'change' if target_changed else 'equal'}")
        print(f"Omarchy shell.json: {CONFIG}; {'activation needed' if config_changed else 'already active'}")
        print(f"required backup: {'yes' if (target_changed and TARGET.exists()) or config_changed else 'no'}")
        print("Native plugin remains installed; no root or network action; no writes")
    else:
        install(expected, data, config, target_changed, config_changed)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
