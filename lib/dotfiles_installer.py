#!/usr/bin/env python3
"""Safe file operations for the dotfiles installer.

Standard library only. This module never runs external commands.
It provides the file primitives that install.sh orchestrates:

- manifest parsing and strict validation
- absolute target expansion inside HOME
- atomic regular-file copy with source mode
- directory compare and managed-tree replacement
- backup root and run-id creation
- absolute-path mirroring without the leading slash
- MANIFEST.tsv append
- exact managed-block replacement
- remote URL identity normalization

Every check operation is read-only: it never creates files, directories,
or backups.
"""

import os
import shutil
import stat
import sys
import tempfile
import time
from pathlib import Path
from urllib.parse import urlparse

VALID_ACTIONS = {
    "merge-block",
    "copy-file",
    "replace-tree",
    "vscode",
    "zed",
    "agents",
    "omarchy-display",
}
VALID_HOSTS = {"linux", "wsl2", "omarchy"}
VALID_RISKS = {"normal", "network-service", "root-power"}
KNOWN_COMPONENTS = {
    "bash",
    "bashrc",
    "git",
    "wallpapers",
    "starship",
    "vscode",
    "zed",
    "agents",
    "omarchy-display",
}
EXPECTED_COMPONENT_ORDER = (
    "bash",
    "bashrc",
    "git",
    "wallpapers",
    "starship",
    "vscode",
    "zed",
    "agents",
    "omarchy-display",
)
ACTION_BY_COMPONENT = {
    "bash": "merge-block",
    "bashrc": "copy-file",
    "git": "copy-file",
    "wallpapers": "replace-tree",
    "starship": "copy-file",
    "vscode": "vscode",
    "zed": "zed",
    "agents": "agents",
    "omarchy-display": "omarchy-display",
}
APPROVED_AGENTS_SOURCE = "https://github.com/guisaliba/agents"
EXPECTED_HOSTS = {
    "bash": "linux,wsl2,omarchy",
    "bashrc": "wsl2",
    "git": "linux,wsl2,omarchy",
    "wallpapers": "linux,wsl2,omarchy",
    "starship": "linux,wsl2,omarchy",
    "vscode": "linux,wsl2,omarchy",
    "zed": "linux,wsl2,omarchy",
    "agents": "linux,wsl2,omarchy",
    "omarchy-display": "omarchy",
}
EXPECTED_DEFAULTS = {
    "bash": "yes",
    "bashrc": "no",
    "git": "yes",
    "wallpapers": "yes",
    "starship": "no",
    "vscode": "no",
    "zed": "no",
    "agents": "no",
    "omarchy-display": "no",
}
EXPECTED_RISKS = {
    "bash": "normal",
    "bashrc": "normal",
    "git": "normal",
    "wallpapers": "normal",
    "starship": "normal",
    "vscode": "normal",
    "zed": "normal",
    "agents": "network-service",
    "omarchy-display": "normal",
}


class InstallerError(Exception):
    pass


def fail(message):
    raise InstallerError(message)


def expand_target(target):
    target = target.strip()
    home = os.environ.get("HOME", "")
    if not home:
        fail("HOME is not set; cannot expand target: " + target)
    if target == "~":
        path = home
    elif target.startswith("~/"):
        path = os.path.join(home, target[2:])
    else:
        path = target
    if not os.path.isabs(path):
        fail("target must be an absolute path or start with ~/: " + target)
    return os.path.abspath(path)


def ensure_within_home(path):
    home = os.environ.get("HOME", "")
    if not home:
        fail("HOME is not set; cannot validate the target path")
    home_absolute = os.path.realpath(os.path.abspath(home))
    path_absolute = os.path.realpath(os.path.abspath(path))
    try:
        common = os.path.commonpath([home_absolute, path_absolute])
    except ValueError:
        common = ""
    if common != home_absolute:
        fail(f"unsafe target outside HOME: {path_absolute}")


def guard_no_symlink(path, label):
    if path.is_symlink():
        fail(f"{label} must not be a symlink: {path}")


def guard_source(path, label, kind):
    guard_no_symlink(path, label)
    if kind == "file":
        if not path.is_file():
            fail(f"{label} must be a regular file: {path}")
    elif kind == "dir":
        if not path.is_dir():
            fail(f"{label} must be a directory: {path}")


def guard_target(path, label, kind):
    guard_no_symlink(path, label)
    ensure_within_home(str(path))
    if path.exists():
        if kind == "file" and not path.is_file():
            fail(f"{label} must be a regular file: {path}")
        if kind == "dir" and not path.is_dir():
            fail(f"{label} must be a directory: {path}")


def validate_tree(path, label):
    path = Path(path)
    guard_source(path, label, "dir")

    def onerror(error):
        fail(f"cannot inspect {label} {error.filename}: {error.strerror}")

    for root, directories, files in os.walk(path, topdown=True, followlinks=False, onerror=onerror):
        for name in directories + files:
            entry = Path(root) / name
            if entry.is_symlink():
                fail(f"{label} contains a symlink: {entry}")
            if not entry.is_dir() and not entry.is_file():
                fail(f"unsupported {label} entry: {entry}")


def atomic_write_bytes(path, data, mode):
    path = Path(path)
    parent = path.parent
    parent.mkdir(mode=0o755, parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=".dotfiles-", dir=str(parent)
    )
    try:
        with os.fdopen(descriptor, "wb") as temporary_file:
            temporary_file.write(data)
            temporary_file.flush()
            os.fsync(temporary_file.fileno())
        os.chmod(temporary_name, mode)
        os.replace(temporary_name, path)
    except BaseException:
        try:
            os.unlink(temporary_name)
        except OSError:
            pass
        raise


def atomic_write_text(content, path, mode, prefix):
    path = Path(path)
    parent = path.parent
    parent.mkdir(mode=0o755, parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix=prefix, dir=str(parent))
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as temporary_file:
            temporary_file.write(content)
            temporary_file.flush()
            os.fsync(temporary_file.fileno())
        os.chmod(temporary_name, mode)
        os.replace(temporary_name, path)
    except BaseException:
        try:
            os.unlink(temporary_name)
        except OSError:
            pass
        raise


def fsync_directory(path):
    try:
        descriptor = os.open(path, os.O_RDONLY)
    except OSError:
        return
    try:
        os.fsync(descriptor)
    except OSError:
        pass
    finally:
        os.close(descriptor)


def mirror_path(target, backup_root):
    return os.path.join(backup_root, target.lstrip(os.sep))


def write_manifest_row(backup_root, target, backup, component, operation):
    manifest = Path(backup_root) / "MANIFEST.tsv"
    if not manifest.exists():
        descriptor = os.open(
            manifest, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600
        )
        os.close(descriptor)
    with open(manifest, "a", encoding="utf-8") as handle:
        handle.write(f"{target}\t{backup}\t{component}\t{operation}\n")


def backup_regular_file(target, backup_root, component, operation):
    backup_path = Path(mirror_path(str(target), backup_root))
    backup_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    shutil.copy2(target, backup_path)
    write_manifest_row(
        backup_root, str(target), str(backup_path), component, operation
    )
    return backup_path


def backup_tree(target, backup_root, component, operation):
    backup_path = Path(mirror_path(str(target), backup_root))
    backup_path.mkdir(mode=0o700, parents=True, exist_ok=True)
    copy_tree_contents(target, backup_path, excludes=())
    write_manifest_row(
        backup_root, str(target), str(backup_path), component, operation
    )
    return backup_path


def iter_tree_entries(source, excludes):
    for path in sorted(source.rglob("*")):
        relative = path.relative_to(source)
        if any(part in excludes for part in relative.parts):
            continue
        yield relative, path


def copy_tree_contents(source, target, excludes):
    entries = list(iter_tree_entries(source, excludes))
    directories = [(relative, path) for relative, path in entries if path.is_dir()]
    files = [(relative, path) for relative, path in entries if path.is_file()]

    for relative, path in directories:
        destination = target / relative
        destination.mkdir(
            mode=stat.S_IMODE(path.stat().st_mode),
            parents=True,
            exist_ok=True,
        )
        os.chmod(destination, stat.S_IMODE(path.stat().st_mode))

    for relative, path in files:
        destination = target / relative
        destination.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
        atomic_write_bytes(
            destination,
            path.read_bytes(),
            stat.S_IMODE(path.stat().st_mode),
        )


def tree_equal(source, target, excludes):
    validate_tree(source, "source tree")
    if not target.is_dir():
        return False
    validate_tree(target, "target tree")
    if stat.S_IMODE(source.stat().st_mode) != stat.S_IMODE(target.stat().st_mode):
        return False
    source_files = {}
    for relative, path in iter_tree_entries(source, excludes):
        if path.is_file():
            source_files[relative] = ("file", stat.S_IMODE(path.stat().st_mode))
        elif path.is_dir():
            source_files[relative] = ("dir", stat.S_IMODE(path.stat().st_mode))
        else:
            source_files[relative] = ("other", None)
    target_files = {}
    for relative, path in iter_tree_entries(target, excludes):
        if path.is_file():
            target_files[relative] = ("file", stat.S_IMODE(path.stat().st_mode))
        elif path.is_dir():
            target_files[relative] = ("dir", stat.S_IMODE(path.stat().st_mode))
        else:
            target_files[relative] = ("other", None)
    if set(source_files) != set(target_files):
        return False
    for relative, (kind, mode) in source_files.items():
        other_kind, other_mode = target_files[relative]
        if kind != other_kind:
            return False
        if kind == "dir" and mode != other_mode:
            return False
        if kind == "file":
            if mode != other_mode:
                return False
            if (source / relative).read_bytes() != (target / relative).read_bytes():
                return False
    return True


def locate_block(lines, start_marker, end_marker, path, allow_absent):
    starts = [index for index, line in enumerate(lines) if line == start_marker]
    ends = [index for index, line in enumerate(lines) if line == end_marker]
    if not starts and not ends:
        if allow_absent:
            return None
        fail(f"missing managed block markers in {path}")
    if len(starts) != 1 or len(ends) != 1 or ends[0] <= starts[0]:
        fail(f"expected one balanced managed block in {path}")
    return starts[0], ends[0]


def build_merged_content(source, target, start_marker, end_marker):
    try:
        source_lines = source.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        fail(f"cannot read source {source}: {exc}")
    source_bounds = locate_block(
        source_lines, start_marker, end_marker, source, allow_absent=False
    )
    canonical = source_lines[source_bounds[0] : source_bounds[1] + 1]
    if target.exists():
        try:
            target_lines = target.read_text(encoding="utf-8").splitlines()
        except OSError as exc:
            fail(f"cannot read target {target}: {exc}")
    else:
        target_lines = []
    target_bounds = locate_block(
        target_lines, start_marker, end_marker, target, allow_absent=True
    )
    if target_bounds is None:
        kept = target_lines
    else:
        kept = target_lines[: target_bounds[0]] + target_lines[target_bounds[1] + 1 :]
    while kept and not kept[-1].strip():
        kept.pop()
    if kept:
        content_lines = kept + [""] + canonical
    else:
        content_lines = canonical
    return "\n".join(content_lines) + "\n"


def validate_manifest_row(
    component, action, source, target, hosts, default, risk, path, line_number
):
    if component not in KNOWN_COMPONENTS:
        fail(f"invalid manifest component at {path}:{line_number}: {component}")
    if action not in VALID_ACTIONS:
        fail(f"invalid manifest action at {path}:{line_number}: {action}")
    if ACTION_BY_COMPONENT[component] != action:
        fail(
            f"manifest action for {component} must be "
            f"{ACTION_BY_COMPONENT[component]} at {path}:{line_number}"
        )
    host_list = hosts.split(",")
    if not hosts or any(not item for item in host_list):
        fail(f"manifest hosts must not be empty at {path}:{line_number}")
    if len(set(host_list)) != len(host_list):
        fail(f"manifest hosts contain a duplicate at {path}:{line_number}")
    for host in host_list:
        if host not in VALID_HOSTS:
            fail(f"invalid manifest host at {path}:{line_number}: {host}")
    if hosts != EXPECTED_HOSTS[component]:
        fail(
            f"manifest hosts for {component} must be {EXPECTED_HOSTS[component]} "
            f"at {path}:{line_number}"
        )
    if default not in ("yes", "no"):
        fail(f"invalid manifest default at {path}:{line_number}: {default}")
    if default != EXPECTED_DEFAULTS[component]:
        fail(
            f"manifest default for {component} must be {EXPECTED_DEFAULTS[component]} "
            f"at {path}:{line_number}"
        )
    if risk not in VALID_RISKS:
        fail(f"invalid manifest risk at {path}:{line_number}: {risk}")
    if risk != EXPECTED_RISKS[component]:
        fail(
            f"manifest risk for {component} must be {EXPECTED_RISKS[component]} "
            f"at {path}:{line_number}"
        )
    if action in ("merge-block", "copy-file", "replace-tree", "vscode", "zed"):
        if not source or os.path.isabs(source) or ".." in Path(source).parts:
            fail(f"unsafe manifest source at {path}:{line_number}: {source}")
        if ".." in Path(target).parts or not (
            target.startswith("~/") or target == "~" or target.startswith("/")
        ):
            fail(f"unsafe manifest target at {path}:{line_number}: {target}")
    elif action == "agents":
        if source != APPROVED_AGENTS_SOURCE:
            fail(f"unsafe manifest agents source at {path}:{line_number}: {source}")
        if ".." in Path(target).parts or not (
            target.startswith("~/") or target == "~" or target.startswith("/")
        ):
            fail(f"unsafe manifest agents target at {path}:{line_number}: {target}")
    elif action == "omarchy-display":
        if not source or os.path.isabs(source) or ".." in Path(source).parts:
            fail(f"unsafe manifest source at {path}:{line_number}: {source}")
        if source != "omarchy/display-plugin" or target != "~/.config/omarchy/plugins/guisaliba.monitor":
            fail(f"invalid omarchy-display source or target at {path}:{line_number}")


def op_manifest(path_text):
    manifest_path = Path(path_text)
    try:
        lines = manifest_path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        fail(f"cannot read manifest {manifest_path}: {exc}")
    rows = []
    seen = set()
    for line_number, line in enumerate(lines, start=1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 7:
            fail(
                f"invalid manifest row at {manifest_path}:{line_number}; "
                "expected 7 tab-separated fields"
            )
        component, action, source, target, hosts, default, risk = fields
        validate_manifest_row(
            component,
            action,
            source,
            target,
            hosts,
            default,
            risk,
            manifest_path,
            line_number,
        )
        if component in seen:
            fail(f"duplicate manifest component at {manifest_path}:{line_number}: {component}")
        seen.add(component)
        rows.append(fields)
    if not rows:
        fail(f"manifest is empty: {manifest_path}")
    actual_order = tuple(row[0] for row in rows)
    missing = sorted(KNOWN_COMPONENTS - seen)
    if missing:
        fail(
            f"manifest is missing component(s) at {manifest_path}: "
            + ", ".join(missing)
        )
    if actual_order != EXPECTED_COMPONENT_ORDER:
        fail(
            f"manifest component order at {manifest_path} must be: "
            + ", ".join(EXPECTED_COMPONENT_ORDER)
        )
    for row in rows:
        print("\t".join(row))


def op_check_file(source_text, target_text):
    source = Path(source_text)
    guard_source(source, "source", "file")
    target = Path(expand_target(target_text))
    guard_target(target, "target", "file")
    if not target.exists():
        print("changed")
        return
    if source.read_bytes() != target.read_bytes():
        print("changed")
        return
    if stat.S_IMODE(source.stat().st_mode) != stat.S_IMODE(target.stat().st_mode):
        print("changed")
        return
    print("equal")


def op_check_tree(source_text, target_text, excludes):
    source = Path(source_text)
    guard_source(source, "source tree", "dir")
    target = Path(expand_target(target_text))
    guard_target(target, "target tree", "dir")
    if tree_equal(source, target, excludes):
        print("equal")
    else:
        print("changed")


def op_check_merge(source_text, target_text, start_marker, end_marker):
    source = Path(source_text)
    guard_source(source, "source", "file")
    target = Path(expand_target(target_text))
    guard_target(target, "target", "file")
    content = build_merged_content(source, target, start_marker, end_marker)
    if target.exists() and content == target.read_text(encoding="utf-8"):
        print("equal")
        return
    print("changed")


def op_copy_file(source_text, target_text, backup_root, component):
    source = Path(source_text)
    guard_source(source, "source", "file")
    target = Path(expand_target(target_text))
    guard_target(target, "target", "file")
    data = source.read_bytes()
    mode = stat.S_IMODE(source.stat().st_mode)
    if target.exists():
        same = (
            target.read_bytes() == data
            and stat.S_IMODE(target.stat().st_mode) == mode
        )
        if same:
            print("equal")
            return
        if backup_root:
            backup_regular_file(target, backup_root, component, "copy-file")
    atomic_write_bytes(target, data, mode)
    print("copied")


def op_tree_replace(source_text, target_text, excludes, backup_root, component):
    source = Path(source_text)
    guard_source(source, "source tree", "dir")
    target = Path(expand_target(target_text))
    guard_target(target, "target tree", "dir")
    if tree_equal(source, target, excludes):
        print("equal")
        return
    target.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
    stage = tempfile.mkdtemp(prefix=".dotfiles-tree-", dir=str(target.parent))
    try:
        os.chmod(stage, stat.S_IMODE(source.stat().st_mode))
        copy_tree_contents(source, Path(stage), excludes)
        if backup_root and target.exists():
            backup_tree(target, backup_root, component, "replace-tree")
        if target.exists():
            old_name = target.parent / (".dotfiles-old-" + os.urandom(4).hex())
            os.replace(target, old_name)
            try:
                os.replace(stage, target)
            except BaseException:
                os.replace(old_name, target)
                raise
            shutil.rmtree(old_name, ignore_errors=True)
        else:
            os.replace(stage, target)
    finally:
        if os.path.exists(stage):
            shutil.rmtree(stage, ignore_errors=True)
    fsync_directory(str(target.parent))
    print("replaced")


def op_merge_block(
    source_text, target_text, start_marker, end_marker, backup_root, component
):
    source = Path(source_text)
    guard_source(source, "source", "file")
    target = Path(expand_target(target_text))
    guard_target(target, "target", "file")
    content = build_merged_content(source, target, start_marker, end_marker)
    if target.exists():
        if content == target.read_text(encoding="utf-8"):
            print("equal")
            return
        mode = stat.S_IMODE(target.stat().st_mode)
        if backup_root:
            backup_regular_file(target, backup_root, component, "merge-block")
    else:
        mode = 0o644
    atomic_write_text(content, target, mode, ".dotfiles-merge-")
    print("merged")


def op_begin_backup(backup_root_text):
    backup_root = Path(backup_root_text)
    guard_no_symlink(backup_root, "backup root")
    ensure_within_home(str(backup_root))
    if backup_root.exists() and not backup_root.is_dir():
        fail(f"backup root must be a directory: {backup_root}")
    backup_root.mkdir(mode=0o700, parents=True, exist_ok=True)
    run_id = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    run_dir = backup_root / run_id
    counter = 1
    while run_dir.exists():
        run_dir = backup_root / f"{run_id}-{counter}"
        counter += 1
    run_dir.mkdir(mode=0o700)
    print(f"{run_dir.name}\t{run_dir}")


def normalize_remote(value):
    value = value.strip()
    if not value:
        fail("empty remote URL")
    if value.startswith("git@") and ":" in value:
        host, path = value.split(":", 1)
        return f"{host.split('@', 1)[-1]}/{path.rstrip('/').removesuffix('.git')}"
    if value.startswith("ssh://"):
        parsed = urlparse(value)
        if not parsed.hostname:
            fail(f"remote URL has no host: {value}")
        return f"{parsed.hostname}/{parsed.path.lstrip('/').rstrip('/').removesuffix('.git')}"
    if "://" in value:
        parsed = urlparse(value)
        if not parsed.hostname:
            fail(f"remote URL has no host: {value}")
        return f"{parsed.hostname}/{parsed.path.lstrip('/').rstrip('/').removesuffix('.git')}"
    return value.rstrip("/").removesuffix(".git")


def op_remote_identity(value):
    print(normalize_remote(value))


def parse_flags(arguments):
    result = {"backup-root": None, "component": None, "excludes": []}
    index = 0
    while index < len(arguments):
        flag = arguments[index]
        if index + 1 >= len(arguments):
            fail(f"missing value for {flag}")
        value = arguments[index + 1]
        if not value:
            fail(f"empty value for {flag}")
        if flag == "--exclude":
            result["excludes"].append(value)
        elif flag == "--backup-root":
            if result["backup-root"] is not None:
                fail("duplicate option: --backup-root")
            result["backup-root"] = value
        elif flag == "--component":
            if result["component"] is not None:
                fail("duplicate option: --component")
            result["component"] = value
        else:
            fail(f"unknown option: {flag}")
        index += 2
    return result


def require_arg_count(arguments, count):
    if len(arguments) != count:
        fail(f"expected {count} arguments, received {len(arguments)}")


def require_min_arg_count(arguments, count):
    if len(arguments) < count:
        fail(f"expected at least {count} arguments, received {len(arguments)}")


def reject_flag(flags, name):
    if flags[name]:
        fail(f"option --{name.replace('_', '-')} is not allowed for this operation")


def reject_all_flags(flags):
    reject_flag(flags, "backup-root")
    reject_flag(flags, "component")
    reject_flag(flags, "excludes")


def run(argv):
    if len(argv) < 2:
        print("usage: dotfiles_installer.py <operation> ...", file=sys.stderr)
        return 2
    operation = argv[1]
    arguments = argv[2:]
    try:
        if operation == "manifest":
            require_arg_count(arguments, 1)
            op_manifest(arguments[0])
        elif operation == "remote-identity":
            require_arg_count(arguments, 1)
            op_remote_identity(arguments[0])
        elif operation == "begin-backup":
            require_arg_count(arguments, 1)
            op_begin_backup(arguments[0])
        elif operation in ("check-file", "copy-file"):
            require_min_arg_count(arguments, 2)
            flags = parse_flags(arguments[2:])
            if operation == "check-file":
                reject_all_flags(flags)
                op_check_file(arguments[0], arguments[1])
            else:
                reject_flag(flags, "excludes")
                op_copy_file(
                    arguments[0],
                    arguments[1],
                    flags["backup-root"],
                    flags["component"] or "?",
                )
        elif operation in ("check-tree", "tree-replace"):
            require_min_arg_count(arguments, 2)
            flags = parse_flags(arguments[2:])
            if operation == "check-tree":
                reject_flag(flags, "backup-root")
                reject_flag(flags, "component")
                op_check_tree(arguments[0], arguments[1], flags["excludes"])
            else:
                op_tree_replace(
                    arguments[0],
                    arguments[1],
                    flags["excludes"],
                    flags["backup-root"],
                    flags["component"] or "?",
                )
        elif operation in ("check-merge", "merge-block"):
            require_min_arg_count(arguments, 4)
            flags = parse_flags(arguments[4:])
            if operation == "check-merge":
                reject_all_flags(flags)
                op_check_merge(
                    arguments[0], arguments[1], arguments[2], arguments[3]
                )
            else:
                reject_flag(flags, "excludes")
                op_merge_block(
                    arguments[0],
                    arguments[1],
                    arguments[2],
                    arguments[3],
                    flags["backup-root"],
                    flags["component"] or "?",
                )
        else:
            print(
                f"usage: dotfiles_installer.py {operation} ...", file=sys.stderr
            )
            return 2
    except (InstallerError, OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(run(sys.argv))
