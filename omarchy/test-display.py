#!/usr/bin/env python3
"""Exercise the installed helper's trial, persistence, and recovery path."""

import copy
import importlib.util
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).parent / "display-plugin/layout.py"
spec = importlib.util.spec_from_file_location("display_layout", SCRIPT)
layout = importlib.util.module_from_spec(spec)
spec.loader.exec_module(layout)


def display(name, x, focused=False):
    return dict(name=name, width=1920, height=1080, refreshRate=60,
                x=x, y=0, scale=1, transform=0, disabled=False, focused=focused)


class DisplayTrialTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        home = Path(self.tmp.name)
        self.config = home / "monitors.lua"
        self.config.write_text('hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })\n')
        self.outputs = {"eDP-1": display("eDP-1", 0), "HDMI-A-1": display("HDMI-A-1", 1920, True)}
        self.calls = []
        self.patchers = [
            patch.object(layout, "CONFIG", self.config),
            patch.object(layout, "STATE", home),
            patch.object(layout, "TRIAL", home / "trial.json"),
            patch.object(layout, "LAST_ERROR", home / "last-error"),
            patch.object(layout, "run", self.command),
            patch.object(layout.subprocess, "Popen"),
        ]
        for patcher in self.patchers:
            patcher.start()
            self.addCleanup(patcher.stop)

    def command(self, *args):
        self.calls.append(args)
        if args == ("hyprctl", "monitors", "all", "-j"):
            return json.dumps(list(self.outputs.values()))
        if args[:2] == ("hyprctl", "eval"):
            rule = args[2]
            name = re.search(r'output = "([^"]+)"', rule).group(1)
            if "disabled = true" in rule:
                self.outputs[name]["disabled"] = True
                return ""
            match = re.search(r'position = "(-?\d+)x(-?\d+)"', rule)
            self.outputs[name]["x"] = int(match.group(1))
            self.outputs[name]["y"] = int(match.group(2))
            self.outputs[name]["transform"] = int(re.search(r'transform = (\d+)', rule).group(1))
            self.outputs[name]["scale"] = float(re.search(r'scale = ([0-9.]+)', rule).group(1))
            self.outputs[name]["disabled"] = False
            return ""
        if args == ("hyprctl", "configerrors"):
            return ""
        if args == ("hyprctl", "reload"):
            return ""
        raise AssertionError(f"unexpected command: {args}")

    def test_trial_confirm_and_reconnect_rule(self):
        layout.begin("HDMI-A-1", "eDP-1", "left", 1)
        self.assertEqual(-1080, self.outputs["HDMI-A-1"]["x"])
        self.assertNotIn(layout.START, self.config.read_text())
        self.assertEqual("Layout saved and verified", layout.keep())
        self.assertIn('position = "-1080x0", scale = 1, transform = 1', self.config.read_text())
        self.assertIn('output = "eDP-1", mode = "1920x1080@60.00", position = "0x0"', self.config.read_text())
        self.assertFalse(layout.TRIAL.exists())
        self.assertEqual(0, layout.rect(self.outputs["eDP-1"])[0])

    def test_revert_restores_live_layout_without_persistence(self):
        initial = self.config.read_bytes()
        layout.begin("HDMI-A-1", "eDP-1", "above", 0)
        trial = json.loads(layout.TRIAL.read_text())
        self.assertIn("verified", layout.rollback(trial))
        self.assertEqual(1920, self.outputs["HDMI-A-1"]["x"])
        self.assertEqual(initial, self.config.read_bytes())

    def test_overlap_is_rejected_without_trial(self):
        self.outputs["DP-1"] = display("DP-1", -1920)
        with self.assertRaisesRegex(layout.LayoutError, "overlaps"):
            layout.begin("HDMI-A-1", "eDP-1", "left", 0)
        self.assertFalse(layout.TRIAL.exists())

    def test_three_screens_confirm_without_moving_third(self):
        self.outputs["DP-1"] = display("DP-1", 3840)
        layout.begin("eDP-1", "HDMI-A-1", "above", 0)
        layout.keep()
        self.assertEqual(3840, self.outputs["DP-1"]["x"])
        self.assertIn('output = "DP-1"', self.config.read_text())

    def test_custom_rule_is_preserved(self):
        self.config.write_text('hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = 1 })\n')
        with self.assertRaisesRegex(layout.LayoutError, "custom rule"):
            layout.begin("HDMI-A-1", "eDP-1", "above", 0)
        self.assertFalse(layout.TRIAL.exists())

    def test_concurrent_edit_blocks_commit(self):
        layout.begin("HDMI-A-1", "eDP-1", "above", 0)
        self.config.write_text(self.config.read_text() + "-- someone else's edit\n")
        with self.assertRaisesRegex(layout.LayoutError, "changed during trial"):
            layout.keep()
        self.assertIn("someone else's edit", self.config.read_text())

    def test_disconnect_cancels_commit(self):
        layout.begin("HDMI-A-1", "eDP-1", "above", 0)
        self.outputs["HDMI-A-1"]["disabled"] = True
        with self.assertRaisesRegex(layout.LayoutError, "disconnected"):
            layout.keep()
        self.assertNotIn(layout.START, self.config.read_text())

    def test_corrupt_baseline_uses_verified_conservative_layout(self):
        layout.begin("HDMI-A-1", "eDP-1", "above", 0)
        trial = json.loads(layout.TRIAL.read_text())
        trial["config"] = "YmFk"  # corrupt bytes, checksum does not match
        self.assertIn("conservative layout verified", layout.rollback(trial))
        self.assertEqual(0, self.outputs["HDMI-A-1"]["x"])

    def test_bad_baseline_geometry_uses_conservative_layout(self):
        layout.begin("HDMI-A-1", "eDP-1", "above", 0)
        trial = json.loads(layout.TRIAL.read_text())
        trial["monitors"]["HDMI-A-1"]["x"] = 0
        self.assertIn("conservative layout verified", layout.rollback(trial))

    def test_scale_keeps_confirmed_position_and_rotation(self):
        layout.begin("HDMI-A-1", "eDP-1", "left", 1)
        layout.keep()
        layout.scale("2")
        self.assertEqual(-1080, self.outputs["HDMI-A-1"]["x"])
        self.assertEqual(1, self.outputs["HDMI-A-1"]["transform"])
        self.assertIn('scale = 2, transform = 1', self.config.read_text())

    def test_single_enabled_output_can_rotate_without_reference(self):
        self.outputs["eDP-1"]["disabled"] = True
        layout.begin("HDMI-A-1", "", "right", 1)
        self.assertEqual(1, self.outputs["HDMI-A-1"]["transform"])
        layout.keep()
        self.assertIn("transform = 1", self.config.read_text())

    def test_second_confirmed_change_keeps_independent_backup(self):
        layout.begin("HDMI-A-1", "eDP-1", "left", 0)
        layout.keep()
        layout.begin("HDMI-A-1", "eDP-1", "above", 0)
        layout.keep()
        self.assertIn('position = "0x-1080"', self.config.read_text())
        self.assertEqual(2, len(list(self.config.parent.glob("monitors.lua.bak.display.*"))))

    def test_recovery_reenables_a_connected_disabled_output(self):
        self.outputs["HDMI-A-1"]["disabled"] = True
        self.outputs["eDP-1"]["disabled"] = True
        self.assertRaises(layout.LayoutError, layout.good_layout, self.outputs)
        layout.conservative_restore()
        self.assertEqual(1, len(layout.active(self.outputs)))
        layout.good_layout(self.outputs)

    def test_reference_move_after_reload_rejects_confirmation(self):
        layout.begin("eDP-1", "HDMI-A-1", "right", 0)
        native = self.command

        def moving_reload(*args):
            result = native(*args)
            if args == ("hyprctl", "reload"):
                self.outputs["HDMI-A-1"]["x"] = 3840
            return result

        with patch.object(layout, "run", moving_reload):
            with self.assertRaisesRegex(layout.LayoutError, "confirmation failed"):
                layout.keep()
        self.assertEqual(1920, self.outputs["HDMI-A-1"]["x"])
        self.assertNotIn(layout.START, self.config.read_text())

    def test_scale_rolls_back_if_reference_moves_on_reload(self):
        layout.begin("HDMI-A-1", "eDP-1", "left", 0)
        layout.keep()
        prior = self.config.read_bytes()
        native = self.command

        def moving_reload(*args):
            result = native(*args)
            if args == ("hyprctl", "reload"):
                self.outputs["eDP-1"]["x"] = 3840
            return result

        with patch.object(layout, "run", moving_reload):
            with self.assertRaisesRegex(layout.LayoutError, "scale failed"):
                layout.scale("2")
        self.assertEqual(prior, self.config.read_bytes())
        self.assertEqual(0, self.outputs["eDP-1"]["x"])
        self.assertEqual(1, self.outputs["HDMI-A-1"]["scale"])


if __name__ == "__main__":
    unittest.main()
