#!/usr/bin/env python3
"""Local Display layout trials; no packaged Omarchy files are changed."""

import base64
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import uuid

CONFIG = Path.home() / ".config/hypr/monitors.lua"
STATE = Path(os.environ.get("XDG_RUNTIME_DIR") or Path.home() / ".local/state") / "omarchy-display-layout"
TRIAL = STATE / "trial.json"
LAST_ERROR = STATE / "last-error"
START = "-- >>> guisaliba Display layout >>>"
END = "-- <<< guisaliba Display layout <<<"
NAME = re.compile(r"^[A-Za-z0-9._-]+$")
SIDES = ("left", "right", "above", "below")
TRANSFORMS = {0, 1, 2, 3}
SECONDS = 20


class LayoutError(Exception):
    pass


def run(*args):
    result = subprocess.run(args, text=True, capture_output=True, check=False)
    if result.returncode:
        raise LayoutError(f"{' '.join(args[:2])}: {result.stderr.strip() or result.stdout.strip()}")
    return result.stdout


def monitors():
    result = json.loads(run("hyprctl", "monitors", "all", "-j"))
    if not isinstance(result, list):
        raise LayoutError("invalid Hyprland monitor state")
    return {m["name"]: m for m in result if isinstance(m, dict) and NAME.fullmatch(str(m.get("name", "")))}


def active(monitors_by_name):
    return {name: m for name, m in monitors_by_name.items() if m.get("disabled") is False}


def rect(m):
    scale = float(m["scale"])
    if not math.isfinite(scale) or scale <= 0:
        raise LayoutError("invalid monitor scale")
    width, height = float(m["width"]), float(m["height"])
    if int(m.get("transform", 0)) % 2:
        width, height = height, width
    return (int(m["x"]), int(m["y"]), math.ceil(width / scale), math.ceil(height / scale))


def intersects(a, b):
    return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]


def good_layout(state):
    enabled = active(state)
    if not enabled:
        raise LayoutError("no enabled display")
    boxes = [(name, rect(m)) for name, m in enabled.items()]
    for index, (name, box) in enumerate(boxes):
        for other, other_box in boxes[index + 1:]:
            if intersects(box, other_box):
                raise LayoutError(f"{name} overlaps {other}")
    return enabled


def target_position(selected, reference, side, transform):
    target = dict(selected, transform=transform)
    _, _, width, height = rect(target)
    x, y, ref_width, ref_height = rect(reference)
    return {
        "left": (x - width, y), "right": (x + ref_width, y),
        "above": (x, y - height), "below": (x, y + ref_height),
    }[side]


def mode(m):
    width, height = int(m["width"]), int(m["height"])
    hz = float(m["refreshRate"])
    if width <= 0 or height <= 0 or not math.isfinite(hz) or hz <= 0:
        raise LayoutError("invalid monitor mode")
    return f"{width}x{height}@{hz:.2f}"


def apply_one(m, x, y, transform):
    name = str(m["name"])
    if not NAME.fullmatch(name) or transform not in TRANSFORMS:
        raise LayoutError("invalid connector or transform")
    scale = float(m["scale"])
    if not math.isfinite(scale) or not 0.5 <= scale <= 8:
        raise LayoutError("invalid scale")
    rule = (f'hl.monitor({{ output = "{name}", mode = "{mode(m)}", '
            f'position = "{x}x{y}", scale = {scale:g}, transform = {transform} }})')
    run("hyprctl", "eval", rule)


def file_hash(data):
    return hashlib.sha256(data).hexdigest()


def current_config():
    if CONFIG.is_symlink() or not CONFIG.is_file():
        raise LayoutError("monitors.lua is missing or is a symlink")
    return CONFIG.read_bytes()


def parsed_config(data):
    text = data.decode("utf-8")
    if text.count(START) != text.count(END) or text.count(START) > 1:
        raise LayoutError("invalid Display layout markers")
    if START in text:
        before, tail = text.split(START, 1)
        managed, after = tail.split(END, 1)
    else:
        before, managed, after = text, "", ""
    return before, managed, after


def rules_for(data, output):
    before, managed, after = parsed_config(data)
    # Fail closed on custom active rules for this connector. Never replace them.
    outside = before + after
    for line in outside.splitlines():
        if line.lstrip().startswith("--"):
            continue
        if re.search(r'hl\.monitor\s*\(\s*\{[^\n]*\boutput\s*=\s*"' + re.escape(output) + r'"', line):
            raise LayoutError(f"custom rule for {output}; edit it manually")
    entries = {}
    for line in managed.splitlines():
        line = line.strip()
        if not line:
            continue
        match = re.fullmatch(r'hl\.monitor\(\{ output = "([A-Za-z0-9._-]+)", mode = "([0-9]+x[0-9]+@[0-9.]+)", position = "(-?[0-9]+x-?[0-9]+)", scale = ([0-9.]+), transform = ([0-3]) \}\)', line)
        if not match or match.group(1) in entries:
            raise LayoutError("unsupported managed monitor rule")
        entries[match.group(1)] = line
    return before, entries, after


def monitor_rule(m):
    return (f'hl.monitor({{ output = "{m["name"]}", mode = "{mode(m)}", '
            f'position = "{int(m["x"])}x{int(m["y"])}", '
            f'scale = {float(m["scale"]):g}, transform = {int(m["transform"])} }})')


def atomic_write(data, expected):
    if file_hash(current_config()) != expected:
        raise LayoutError("monitors.lua changed during layout trial")
    fd, path = tempfile.mkstemp(prefix=".monitors.lua.", dir=CONFIG.parent)
    try:
        os.fchmod(fd, CONFIG.stat().st_mode & 0o777)
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        if file_hash(current_config()) != expected:
            raise LayoutError("monitors.lua changed during write")
        os.replace(path, CONFIG)
    finally:
        if os.path.exists(path):
            os.unlink(path)


def save_json(path, obj):
    temp = path.with_name(path.name + ".new")
    with open(temp, "w", encoding="utf-8") as handle:
        json.dump(obj, handle)
    os.chmod(temp, 0o600)
    os.replace(temp, path)


def verified_restore(trial):
    expected = trial.get("config_hash")
    original = base64.b64decode(trial["config"])
    if file_hash(original) != expected:
        raise LayoutError("baseline configuration snapshot is corrupt")
    if trial.get("written_hash") and file_hash(current_config()) == trial["written_hash"]:
        atomic_write(original, trial["written_hash"])
        run("hyprctl", "reload")
    before = trial["monitors"]
    good_layout(before)
    live = monitors()
    for name, m in before.items():
        if name in active(live) and not m.get("disabled", True):
            apply_one(m, int(m["x"]), int(m["y"]), int(m.get("transform", 0)))
    live = monitors()
    good_layout(live)
    for name, m in before.items():
        if name in active(live) and not m.get("disabled", True):
            if rect(live[name]) != rect(m) or int(live[name]["transform"]) != int(m["transform"]):
                raise LayoutError("baseline readback differs")


def conservative_restore():
    live = monitors()
    enabled = active(live)
    candidates = enabled or live
    if not candidates:
        raise LayoutError("no connected output for recovery")
    selected = next((m for m in candidates.values() if m.get("focused")), None)
    if selected is None:
        selected = next((m for m in candidates.values() if not m["name"].startswith(("eDP-", "LVDS-", "DSI-"))), next(iter(candidates.values())))
    for name in enabled:
        if name != selected["name"]:
            run("hyprctl", "eval", f'hl.monitor({{ output = "{name}", disabled = true }})')
    run("hyprctl", "eval", f'hl.monitor({{ output = "{selected["name"]}", mode = "preferred", position = "0x0", scale = 1, transform = 0 }})')
    recovered = monitors()
    if selected["name"] not in active(recovered):
        raise LayoutError("recovery output did not become active")
    # Other connected screens may still overlap: do not claim success without proof.
    good_layout(recovered)


def rollback(trial):
    try:
        verified_restore(trial)
        return "Previous layout restored and verified"
    except (LayoutError, ValueError, KeyError, OSError) as error:
        conservative_restore()
        return f"Baseline recovery failed ({error}); conservative layout verified"


def begin(output, reference, side, transform):
    if TRIAL.exists():
        raise LayoutError("a Display layout trial is already active")
    if side not in SIDES or transform not in TRANSFORMS or not NAME.fullmatch(output) or (reference and not NAME.fullmatch(reference)) or output == reference:
        raise LayoutError("invalid display selection")
    live = monitors()
    enabled = good_layout(live)
    if run("hyprctl", "configerrors").strip():
        raise LayoutError("current Hyprland configuration has errors; no safe baseline")
    if output not in enabled or (reference and reference not in enabled):
        raise LayoutError("selected displays must be connected and enabled")
    if not reference and len(enabled) != 1:
        raise LayoutError("select a reference display for placement")
    data = current_config()
    rules_for(data, output)
    for name in enabled:
        rules_for(data, name)
    x, y = (target_position(live[output], live[reference], side, transform)
            if reference else (int(live[output]["x"]), int(live[output]["y"])))
    candidate = dict(live[output], x=x, y=y, transform=transform)
    for name, m in enabled.items():
        if name != output and intersects(rect(candidate), rect(m)):
            raise LayoutError(f"requested position overlaps {name}")
    trial = {"id": uuid.uuid4().hex, "deadline": time.monotonic() + SECONDS,
             "output": output, "reference": reference, "side": side, "monitors": live,
             "config_hash": file_hash(data), "config": base64.b64encode(data).decode(),
             "x": x, "y": y, "transform": transform}
    save_json(TRIAL, trial)
    try:
        LAST_ERROR.unlink(missing_ok=True)
        subprocess.Popen([sys.executable, __file__, "watch", trial["id"]],
                         start_new_session=True, stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        apply_one(live[output], x, y, transform)
        applied = monitors()
        if output not in active(applied) or rect(applied[output]) != rect(candidate):
            raise LayoutError("trial layout readback differs")
        good_layout(applied)
    except Exception:
        try:
            rollback(trial)
        finally:
            TRIAL.unlink(missing_ok=True)
        raise
    return f"Trial active for {SECONDS} seconds"


def keep():
    if not TRIAL.exists():
        raise LayoutError("no active layout trial")
    trial = json.loads(TRIAL.read_text())
    if time.monotonic() >= trial["deadline"]:
        raise LayoutError("trial expired")
    data = current_config()
    if file_hash(data) != trial["config_hash"]:
        raise LayoutError("monitors.lua changed during trial")
    live = monitors()
    if trial["output"] not in active(live) or (trial["reference"] and trial["reference"] not in active(live)):
        raise LayoutError("a display disconnected during trial")
    good_layout(live)
    selected = live[trial["output"]]
    if int(selected["transform"]) != trial["transform"] or int(selected["x"]) != trial["x"] or int(selected["y"]) != trial["y"]:
        raise LayoutError("trial display state changed")
    before, entries, after = rules_for(data, trial["output"])
    entries[trial["output"]] = monitor_rule(selected)
    for name, monitor in active(live).items():
        if name != trial["output"]:
            rules_for(data, name)
            entries[name] = monitor_rule(monitor)
    text = before.rstrip("\n") + "\n\n" + START + "\n" + "\n".join(entries[name] for name in sorted(entries)) + "\n" + END + "\n" + after.lstrip("\n")
    # Backup before writing; keep the exact pre-trial bytes for recovery.
    backup = CONFIG.with_name("monitors.lua.bak.display." + uuid.uuid4().hex)
    backup.write_bytes(data)
    backup.chmod(CONFIG.stat().st_mode & 0o777)
    trial["written_hash"] = file_hash(text.encode())
    save_json(TRIAL, trial)
    atomic_write(text.encode(), trial["config_hash"])
    try:
        run("hyprctl", "reload")
        errors = run("hyprctl", "configerrors").strip()
        if errors:
            raise LayoutError(f"Hyprland configuration error: {errors}")
        updated = monitors()
        good_layout(updated)
        if trial["output"] not in active(updated) or rect(updated[trial["output"]]) != rect(selected):
            raise LayoutError("confirmed layout readback differs")
        if trial["reference"]:
            reference = trial["reference"]
            if reference not in active(updated) or rect(updated[reference]) != rect(live[reference]):
                raise LayoutError("reference display moved after confirmation")
            position = target_position(updated[trial["output"]], updated[reference], trial["side"], trial["transform"])
            if position != (int(updated[trial["output"]]["x"]), int(updated[trial["output"]]["y"])):
                raise LayoutError("confirmed relative placement differs")
        for name, monitor in active(trial["monitors"]).items():
            if name == trial["output"]:
                continue
            if name not in active(updated) or rect(updated[name]) != rect(monitor):
                raise LayoutError(f"other display moved after confirmation: {name}")
        if time.monotonic() >= trial["deadline"]:
            raise LayoutError("trial expired during confirmation")
    except (LayoutError, OSError) as error:
        message = rollback(trial)
        TRIAL.unlink(missing_ok=True)
        raise LayoutError(f"confirmation failed ({error}); {message}") from error
    TRIAL.unlink(missing_ok=True)
    return "Layout saved and verified"


def status():
    if LAST_ERROR.exists():
        return "error:" + LAST_ERROR.read_text().strip()
    if not TRIAL.exists():
        return "idle"
    trial = json.loads(TRIAL.read_text())
    return f"trial:{max(0, math.ceil(trial['deadline'] - time.monotonic()))}"


def scale(value):
    if TRIAL.exists():
        raise LayoutError("finish the layout trial before changing scale")
    # Native scaling remains native when there is no confirmed layout.
    live = monitors()
    enabled = good_layout(live)
    focused = next((m for m in enabled.values() if m.get("focused")), None)
    if focused is None:
        raise LayoutError("no focused display")
    data = current_config()
    _, entries, _ = rules_for(data, focused["name"])
    if focused["name"] not in entries:
        return run("omarchy-hyprland-monitor-scaling", value).strip()
    requested = float(value)
    if not math.isfinite(requested) or not 1 <= requested <= 4:
        raise LayoutError("invalid requested scale")
    # Hyprland uses clean 1/120th logical pixel divisors (same as native scale CLI).
    width, height = int(focused["width"]), int(focused["height"])
    divisor = math.gcd(width * 120, height * 120)
    unit = min(round(requested * 120), divisor)
    while divisor % unit:
        unit += 1
    new_scale = unit / 120
    focused = dict(focused, scale=new_scale)
    for name, m in enabled.items():
        if name != focused["name"] and intersects(rect(focused), rect(m)):
            raise LayoutError(f"scale would overlap {name}")
    updated = None
    trial = {"config": base64.b64encode(data).decode(), "config_hash": file_hash(data),
             "monitors": live}
    try:
        apply_one(focused, int(focused["x"]), int(focused["y"]), int(focused["transform"]))
        before, entries, after = rules_for(data, focused["name"])
        entries[focused["name"]] = monitor_rule(focused)
        gdk = max(1, int(new_scale + 0.5))
        before = re.sub(r"(?m)^local omarchy_gdk_scale = [0-9]+$",
                        f"local omarchy_gdk_scale = {gdk}", before)
        before = re.sub(r"(?m)^local omarchy_monitor_scale = [0-9.]+$",
                        f"local omarchy_monitor_scale = {new_scale:g}", before)
        updated = before.rstrip("\n") + "\n\n" + START + "\n" + "\n".join(entries[name] for name in sorted(entries)) + "\n" + END + "\n" + after.lstrip("\n")
        backup = CONFIG.with_name("monitors.lua.bak.display." + uuid.uuid4().hex)
        backup.write_bytes(data)
        backup.chmod(CONFIG.stat().st_mode & 0o777)
        atomic_write(updated.encode(), file_hash(data))
        trial["written_hash"] = file_hash(updated.encode())
        run("hyprctl", "reload")
        if run("hyprctl", "configerrors").strip():
            raise LayoutError("scale produced configuration errors")
        result = good_layout(monitors())
        for name, m in enabled.items():
            if name not in result or int(result[name]["x"]) != int(m["x"]) or int(result[name]["y"]) != int(m["y"]) or int(result[name]["transform"]) != int(m["transform"]):
                raise LayoutError("scale changed a display's position or orientation")
        if abs(float(result[focused["name"]]["scale"]) - new_scale) > 0.001:
            raise LayoutError("scale readback differs")
    except (LayoutError, OSError) as error:
        recovery = rollback(trial)
        raise LayoutError(f"scale failed ({error}); {recovery}") from error
    return "Scale saved without changing layout"


def state():
    lines = run("omarchy-monitor-state").splitlines()
    if len(lines) < 8:
        raise LayoutError("native Display state is incomplete")
    all_monitors = monitors()
    entries = json.loads(lines[7])
    for entry in entries:
        m = all_monitors.get(entry.get("name"), {})
        entry.update(x=m.get("x", 0), y=m.get("y", 0), scale=m.get("scale", 1),
                     transform=m.get("transform", 0))
    lines[7] = json.dumps(entries, separators=(",", ":"))
    return "\n".join(lines[:8])


def main(args):
    STATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    if STATE.is_symlink() or STATE.stat().st_uid != os.getuid():
        raise LayoutError("unsafe layout state directory")
    lock = STATE / "lock"
    with open(lock, "a+") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        op = args[0] if args else ""
        if op == "state" and len(args) == 1:
            return state()
        if op == "status" and len(args) == 1:
            return status()
        if op == "begin" and len(args) == 5:
            return begin(args[1], args[2], args[3], int(args[4]))
        if op == "keep" and len(args) == 1:
            return keep()
        if op == "revert" and len(args) == 1:
            if not TRIAL.exists():
                raise LayoutError("no active layout trial")
            trial = json.loads(TRIAL.read_text())
            message = rollback(trial)
            TRIAL.unlink(missing_ok=True)
            return message
        if op == "scale" and len(args) == 2:
            return scale(args[1])
        if op == "watch" and len(args) == 2:
            # Release lock while waiting so UI actions can commit or cancel.
            fcntl.flock(handle, fcntl.LOCK_UN)
            while True:
                time.sleep(0.5)
                fcntl.flock(handle, fcntl.LOCK_EX)
                try:
                    if not TRIAL.exists():
                        return ""
                    trial = json.loads(TRIAL.read_text())
                    if trial["id"] != args[1]:
                        return ""
                    live = active(monitors())
                    if (time.monotonic() < trial["deadline"]
                            and trial["output"] in live
                            and (not trial["reference"] or trial["reference"] in live)):
                        continue
                    try:
                        message = rollback(trial)
                    except (LayoutError, ValueError, OSError) as error:
                        LAST_ERROR.write_text(str(error) + "\n")
                        return "rollback failed: " + str(error)
                    TRIAL.unlink(missing_ok=True)
                    return message
                finally:
                    fcntl.flock(handle, fcntl.LOCK_UN)
        raise LayoutError("usage: layout.py state|status|begin OUTPUT REFERENCE SIDE ROTATION|keep|revert|scale VALUE")


if __name__ == "__main__":
    try:
        print(main(sys.argv[1:]))
    except (LayoutError, OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print(f"Display layout: {exc}", file=sys.stderr)
        sys.exit(1)
