"""Mobile mode/resource contracts; no APK generation, signing or uploads."""
from pathlib import Path
import unittest

import mobile_release as delivery
from mobile_comparison_resources import resources


class MobileModeTests(unittest.TestCase):
    def setUp(self):
        self.project = next(p for p in delivery.REPO.iterdir() if p.is_dir() and (p / "project.godot").is_file())

    def test_all_modes_have_real_entry_controller_and_install_notes(self):
        for mode, spec in delivery.PLAY_MODES.items():
            with self.subTest(mode=mode):
                for key in ["main_scene", "entry_script"]:
                    self.assertTrue((self.project / spec[key][6:]).is_file())
                self.assertTrue((delivery.REPO / spec["install"]).is_file())

    def test_journey_contains_live_hud_flow_fonts_and_dynamic_line_frames(self):
        selected = set(resources(self.project, "magazine-journey"))
        for path in ["redesign/magazine_journey.gd", "redesign/samples/hud/combat_journey_hud.tscn", "scripts/core/run_manager.gd",
                     "redesign/samples/hud/journey_flow.tscn", "redesign/samples/hud/journey_route.tscn",
                     "assets/fonts/NeoDunggeunmoPro-Regular.ttf", "assets/ui/line_theme_20261101/px_active.png",
                     "assets/ui/line_theme_20261101/px_fire.png"]:
            self.assertIn("res://" + path, selected)
        self.assertFalse(any("/tests/" in uri for uri in selected))
        # Existing no-argument callers retain the independent comparison entry.
        self.assertEqual(resources(self.project), resources(self.project, "weapon-magazine"))
        self.assertNotIn(delivery.PLAY_MODES["magazine-journey"]["main_scene"], resources(self.project))

    def test_live_hud_includes_dynamic_feedback_audio(self):
        selected = set(resources(self.project, "magazine-journey"))
        self.assertIn("res://redesign/samples/hud/combat_hud_feedback.gd", selected)
        audio_files = list((self.project / "assets/audio/feedback").glob("*.wav"))
        self.assertEqual(len(audio_files), 12)
        for audio in audio_files:
            self.assertIn("res://" + audio.relative_to(self.project).as_posix(), selected)

    def test_compiled_mode_validation_rejects_mislabeled_or_incomplete_packs(self):
        required = {"project.binary", "redesign/model.gdc", "redesign/content.gdc", "redesign/campaign.gdc",
                    "redesign/magazine_journey.gdc", "redesign/line_skin.gdc",
                    "redesign/samples/hud/combat_journey_hud.tscn.remap", "redesign/samples/hud/combat_journey_hud.gdc",
                    "redesign/samples/hud/combat_hud_presenter.gdc", "redesign/samples/hud/journey_flow_presenter.gdc",
                    "redesign/samples/hud/journey_flow.tscn.remap", "redesign/samples/hud/journey_route.tscn.remap"}
        manifest = {"play_mode": "magazine-journey", "main_scene": delivery.PLAY_MODES["magazine-journey"]["main_scene"]}
        delivery.verify_mode_resources(manifest, required, prefix="")
        delivery.verify_mode_resources(manifest, {"assets/" + path for path in required})
        for path in required:
            with self.subTest(missing=path), self.assertRaises(ValueError):
                delivery.verify_mode_resources(manifest, required - {path}, prefix="")
        for changes in [{"play_mode": "unknown"}, {"play_mode": "campaign"}, {"main_scene": delivery.PLAY_MODES["weapon-magazine"]["main_scene"]}]:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                delivery.verify_mode_resources({**manifest, **changes}, required, prefix="")

    def test_existing_campaign_and_comparison_still_validate(self):
        for mode in ["campaign", "weapon-magazine"]:
            spec = delivery.PLAY_MODES[mode]
            names = {"project.binary", "redesign/model.gdc", "redesign/content.gdc",
                     spec["main_scene"][6:] + ".remap", spec["entry_script"][6:-3] + ".gdc"}
            if mode == "weapon-magazine":
                names.update(f"redesign/samples/combat_weapon_{gun}_{role}.json" for gun in ["single", "burst", "scatter", "heavy", "amplifier"] for role in ["breach", "boss", "sweep", "payoff"])
            delivery.verify_mode_resources({"play_mode": mode, "main_scene": spec["main_scene"]}, names, prefix="")


if __name__ == "__main__":
    unittest.main()
