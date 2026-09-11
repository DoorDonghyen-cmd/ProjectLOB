import unittest
from analyze_ammo_hand import analyze, summarize


def sample(variant="A", seed=1):
    basic = {"id": "basic", "is_basic": True}
    marker = {"id": "marker", "is_basic": False, "specialty": "accuracy"}
    return {
        "result": "won", "ammo_hand": {"comparison_variant": variant},
        "comparison": {"seed": seed, "scenario": "armor", "gun_id": "revolver",
                       "parts": [], "deck": ["marker"], "policy": "test"},
        "loadouts": [{"fire_order": [marker, basic], "available_tactical": [marker]}],
        # Only one shot was fired: the full planned order is still two bullets.
        "shots": [{"bullet": marker, "effective": True}],
    }


class ComparisonTests(unittest.TestCase):
    def test_counts_decisions_separately_from_fired_shots(self):
        report = summarize([sample(), sample()])
        self.assertEqual(report["shots"], 2)
        self.assertEqual(report["firing_orders"][0]["ids"], ["marker", "basic"])
        self.assertEqual(report["repeated_order_fraction"], 0.5)
        self.assertEqual(report["basic_shot_fraction"], 0)

    def test_requires_identical_seed_and_conditions(self):
        report = analyze([("a", sample()), ("b", sample("B", 2))])
        self.assertEqual(report["matched_pairs"], 0)
        self.assertEqual(len(report["rejected"]), 2)

    def test_rejects_duplicate_runs_instead_of_overweighting(self):
        report = analyze([("a", sample()), ("a2", sample()), ("b", sample("B"))])
        self.assertEqual(report["matched_pairs"], 0)

    def test_missing_loadout_data_is_unknown(self):
        encounter = sample()
        del encounter["loadouts"]
        report = summarize([encounter])
        self.assertIsNone(report["repeated_order_fraction"])
        self.assertEqual(report["missing_loadout_logs"], 1)

    def test_valid_pairs_do_not_claim_human_fun(self):
        report = analyze([("a", sample()), ("b", sample("B"))])
        self.assertEqual(report["matched_pairs"], 1)
        self.assertEqual(report["decision"], "HUMAN_PLAY_REQUIRED")
        self.assertIsNone(report["metrics"]["B"]["human_meaningful_choices"])


if __name__ == "__main__":
    unittest.main()
