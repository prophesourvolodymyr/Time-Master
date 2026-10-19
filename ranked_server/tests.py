import copy
import json
import os
import secrets
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from fastapi.testclient import TestClient
from . import app as service
from .rules import Tracker, assess, elo, VERSION, ADVANCED


def pose(t, bottom=False, squat=False):
    points = {}
    if squat:
        values = {"Shoulder": (0.38, 0.65), "Hip": (0.40, 0.35), "Knee": (0.28, 0.37), "Ankle": (0.32, 0.08), "Elbow": (0.35, 0.5), "Wrist": (0.3, 0.45)} if bottom else {"Shoulder": (0.32, 0.8), "Hip": (0.32, 0.55), "Knee": (0.32, 0.3), "Ankle": (0.32, 0.08), "Elbow": (0.26, 0.65), "Wrist": (0.26, 0.5)}
        for side in ("left", "right"):
            for name, (x, y) in values.items():
                points[side + name] = dict(x=x + (0.2 if side == "right" else 0), y=y, confidence=0.99)
        points["nose"] = dict(x=0.4, y=0.92 if not bottom else 0.78, confidence=0.99)
    else:
        values = {"Shoulder": (0.25, 0.4), "Elbow": (0.4, 0.4), "Wrist": (0.25, 0.25), "Hip": (0.5, 0.3375), "Knee": (0.68, 0.2925), "Ankle": (0.85, 0.25)} if bottom else {"Shoulder": (0.25, 0.55), "Elbow": (0.25, 0.4), "Wrist": (0.25, 0.25), "Hip": (0.5, 0.425), "Knee": (0.68, 0.335), "Ankle": (0.85, 0.25)}
        for side in ("left", "right"):
            for name, (x, y) in values.items():
                points[side + name] = dict(x=x, y=y + (0.1 if side == "right" else 0), confidence=0.99)
        points["nose"] = dict(x=0.15, y=0.55 if bottom else 0.7, confidence=0.99)
    return dict(time=round(t, 4), aspect=1.0, people=1, joints=points, light=0.5, cameraMoving=False, diamondContact=None)


class TrackingTests(unittest.TestCase):
    def calibrated(self, variation="standardPushUp"):
        tracker = Tracker(variation)
        for i in range(-30, 0):
            tracker.consume(pose(i / 10, squat="Squat" in variation))
        self.assertTrue(tracker.calibrated)
        return tracker

    def test_stationary_pose_stays_zero_and_complete_cycle_counts_once(self):
        tracker = self.calibrated()
        for i in range(20):
            tracker.consume(pose(i / 10))
        self.assertEqual(tracker.score, 0)
        for i in range(20, 25):
            tracker.consume(pose(i / 10, True))
        for i in range(25, 35):
            tracker.consume(pose(i / 10))
        self.assertEqual(tracker.score, 1)

    def test_half_rep_at_go_and_repeated_bottom_fragments_do_not_score(self):
        tracker = self.calibrated()
        for i in range(10):
            tracker.consume(pose(i / 10, True))
        for i in range(10, 20):
            tracker.consume(pose(i / 10))
        self.assertEqual(tracker.score, 0)
        for i in range(20, 40):
            tracker.consume(pose(i / 10, i % 2 == 0))
        self.assertEqual(tracker.score, 0)

    def test_pause_must_be_continuous_and_tempo_requires_three_second_descent(self):
        paused = self.calibrated("pausedPushUp")
        for i in range(5):
            paused.consume(pose(i / 10))
        for i in range(5, 11):
            paused.consume(pose(i / 10, True))
        for i in range(11, 17):
            paused.consume(pose(i / 10))
        self.assertEqual(paused.score, 0)
        for i in range(17, 30):
            paused.consume(pose(i / 10, True))
        for i in range(30, 35):
            paused.consume(pose(i / 10))
        self.assertEqual(paused.score, 1)
        tempo = self.calibrated("tempoPushUp")
        for i in range(5): tempo.consume(pose(i / 10))
        for i in range(5, 10): tempo.consume(pose(i / 10, True))
        for i in range(10, 15): tempo.consume(pose(i / 10))
        self.assertEqual(tempo.score, 0)

    def test_hold_preserves_longest_segment_not_sum_and_no_ghost_time(self):
        tracker = self.calibrated("highPlank")
        for i in range(51): tracker.consume(pose(i / 10))
        self.assertAlmostEqual(tracker.score, 5)
        bad = pose(5.1); bad["people"] = 0
        tracker.consume(bad)
        for i in range(52, 102): tracker.consume(pose(i / 10))
        self.assertAlmostEqual(tracker.score, 5)
        tracker.consume(pose(20))
        self.assertAlmostEqual(tracker.score, 5)
        self.assertFalse(tracker.calibrated)

    def test_occlusion_multiple_people_camera_motion_and_deadline_break_scoring(self):
        for invalidity in ("people", "confidence", "cameraMoving", "light"):
            tracker = self.calibrated("highPlank")
            for i in range(20): tracker.consume(pose(i / 10))
            score = tracker.score
            bad = pose(2)
            if invalidity == "people": bad["people"] = 2
            elif invalidity == "confidence": bad["joints"]["leftAnkle"]["confidence"] = 0.1
            elif invalidity == "light": bad["light"] = 0.01
            else: bad["cameraMoving"] = True
            tracker.consume(bad)
            tracker.consume(pose(2.1))
            self.assertEqual(tracker.score, score)
        tracker = self.calibrated("highPlank")
        for i in range(601): tracker.consume(pose(i / 10))
        score = tracker.score
        tracker.consume(pose(60.1))
        self.assertEqual(tracker.score, score)
        self.assertLessEqual(score, 60)


    def test_asymmetric_depth_does_not_qualify_for_complete_repetitions(self):
        partial = pose(0, bottom=True)
        partial["joints"]["rightElbow"] = dict(x=0.25, y=0.375, confidence=0.99)
        self.assertFalse(assess(partial, "standardPushUp")["bottom"])
        squat = pose(0, bottom=True, squat=True)
        squat["joints"]["rightKnee"] = dict(x=0.6, y=0.215, confidence=0.99)
        self.assertFalse(assess(squat, "standardSquat")["bottom"])
    def test_exact_stance_and_diamond_hand_evidence(self):
        self.assertTrue(assess(pose(0, squat=True), "standardSquat")["valid"])
        self.assertTrue(assess(pose(0, bottom=True, squat=True), "standardSquat")["bottom"])
        self.assertFalse(assess(pose(0, squat=True), "wideSquat")["valid"])
        self.assertFalse(assess(pose(0), "diamondPushUp")["valid"])

    def test_elo_boundaries_draws_and_provisional_factors(self):
        self.assertEqual(elo(1000, 1000, 0.5, 0, 0), (1000, 1000))
        self.assertEqual(elo(1000, 1000, 1, 0, 0), (1020, 980))
        self.assertEqual(elo(1000, 1000, 1, 5, 5), (1012, 988))
        self.assertEqual(elo(5000, 0, 1, 0, 0), (5000, 0))
        a, b = elo(800, 1200, 1, 10, 10)
        self.assertGreater(a - 800, 12)
        self.assertLess(b, 1200)


class CompetitionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.previous_path, self.previous_now = service.DB_PATH, service.now
        service.DB_PATH = self.temp.name + "/ranked.sqlite3"
        self.clock = 1000000.0
        service.now = lambda: self.clock
        os.environ["RANKED_REQUIRE_TLS"] = "false"
        service.initialize()
        self.client = TestClient(service.app)
        self.a = self.register("athlete-a")
        self.b = self.register("athlete-b")

    def tearDown(self):
        self.client.close()
        service.DB_PATH, service.now = self.previous_path, self.previous_now
        self.temp.cleanup()

    def register(self, name):
        response = self.client.post("/v1/auth/register", json=dict(login=name, password="correct-horse-battery", displayName=name, listed=True))
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def headers(self, auth): return {"Authorization": "Bearer " + auth["accessToken"]}
    def get(self, path, auth): return self.client.get("/v1/" + path, headers=self.headers(auth))
    def post(self, path, auth, body=None): return self.client.post("/v1/" + path, headers=self.headers(auth), json=body)

    def pair(self, variation="standardPushUp"):
        for auth in (self.a, self.b):
            r = self.post("queue", auth, dict(variation=variation, ruleVersion=VERSION, requestID=secrets.token_hex(16)))
            self.assertEqual(r.status_code, 200, r.text)
        m = self.get("state", self.a).json()["match"]
        for _ in range(20):
            if m is not None: break
            self.clock += 5
            self.get("state", self.a)
            self.get("state", self.b)
            service.tick()
            m = self.get("state", self.a).json()["match"]
        self.assertIsNotNone(m)
        return m

    def start(self, variation="standardPushUp"):
        m = self.pair(variation)
        calibration = [pose(100 + i / 10, squat="Squat" in variation) for i in range(20)]
        for auth in (self.a, self.b):
            response = self.post(f'matches/{m["id"]}/ready', auth, dict(ready=True, calibration=calibration))
            self.assertEqual(response.status_code, 200, response.text)
        m = response.json()["match"]
        self.clock = m["startAt"]
        service.tick()
        return self.get("matches/" + m["id"], self.a).json()["match"]

    def heartbeat(self, mid):
        for auth in (self.a, self.b):
            self.get("matches/" + mid, auth)

    def test_queue_idempotency_atomic_claim_exact_variation_and_cancel(self):
        request = dict(variation="standardPushUp", ruleVersion=VERSION, requestID=secrets.token_hex(16))
        with ThreadPoolExecutor(max_workers=6) as pool:
            results = list(pool.map(lambda _: self.post("queue", self.a, request), range(6)))
        self.assertTrue(all(r.status_code == 200 for r in results))
        self.post("queue", self.b, dict(variation="widePushUp", ruleVersion=VERSION, requestID=secrets.token_hex(16)))
        self.assertIsNone(self.get("state", self.a).json()["match"])
        self.post("queue/cancel", self.b)
        self.post("queue", self.b, dict(variation="standardPushUp", ruleVersion=VERSION, requestID=secrets.token_hex(16)))
        m = self.get("state", self.a).json()["match"]
        self.assertEqual(len(m["participants"]), 2)
        self.post("queue/cancel", self.a)
        self.assertEqual(self.get("matches/" + m["id"], self.b).json()["match"]["state"], "cancelled")
        self.post("queue", self.a, request)
        self.assertIsNone(self.get("state", self.a).json()["queue"])
        self.assertEqual(self.get("me", self.a).json()["allowances"][0]["remaining"], 10)

    def test_shared_countdown_pre_go_cancel_and_after_go_forfeit(self):
        m = self.start()
        a = self.get("matches/" + m["id"], self.a).json()["match"]
        b = self.get("matches/" + m["id"], self.b).json()["match"]
        self.assertEqual(a["startAt"], b["startAt"])
        self.assertEqual(a["endAt"] - a["startAt"], 60)
        self.assertEqual(a["state"], "live")
        self.post("matches/" + m["id"] + "/leave", self.a)
        self.post("matches/" + m["id"] + "/leave", self.a)
        terminal = self.get("matches/" + m["id"], self.a).json()["match"]
        self.assertEqual(terminal["state"], "forfeited")
        self.assertEqual(next(p for p in terminal["participants"] if p["isYou"])["afterRating"], 980)
        self.assertEqual(self.get("me", self.a).json()["ratings"][0]["games"], 1)
        self.assertEqual(self.get("me", self.a).json()["allowances"][0]["remaining"], 9)

    def test_pre_go_cancellation_and_start_race_has_one_consistent_result(self):
        m = self.pair()
        calibration = [pose(100 + i / 10) for i in range(20)]
        for auth in (self.a, self.b): self.post(f'matches/{m["id"]}/ready', auth, dict(ready=True, calibration=calibration))
        self.clock += 3.999
        self.post("matches/" + m["id"] + "/leave", self.a)
        self.clock += 0.001
        service.tick()
        terminal = self.get("matches/" + m["id"], self.b).json()["match"]
        self.assertEqual(terminal["state"], "cancelled")
        self.assertEqual(self.get("me", self.a).json()["allowances"][0]["remaining"], 10)

    def test_family_allowance_shared_across_variations_and_exact_expiry(self):
        for i in range(10):
            m = self.start("standardPushUp" if i % 2 == 0 else "pausedPushUp")
            self.post("matches/" + m["id"] + "/leave", self.a)
        snapshot = self.get("me", self.a).json()
        self.assertEqual([a["remaining"] for a in snapshot["allowances"]], [0, 10, None])
        denied = self.post("queue", self.a, dict(variation="widePushUp", ruleVersion=VERSION, requestID=secrets.token_hex(16)))
        self.assertEqual(denied.status_code, 429)
        next_slot = snapshot["allowances"][0]["nextSlot"]
        uid = self.uid(self.a)
        self.clock = next_slot - 0.0001
        with service.transaction() as db: self.assertEqual(service.allowance(db, uid, "pushUps", self.clock)["remaining"], 0)
        self.clock = next_slot
        with service.transaction() as db: self.assertEqual(service.allowance(db, uid, "pushUps", self.clock)["remaining"], 1)

    def uid(self, auth):
        with service.transaction() as db:
            return db.execute("SELECT user_id FROM sessions WHERE access_hash=?", (service.digest(auth["accessToken"]),)).fetchone()[0]

    def test_expired_readiness_and_disconnect_grace(self):
        m = self.pair()
        self.clock += 9
        service.tick()
        self.assertEqual(self.get("matches/" + m["id"], self.a).json()["match"]["state"], "cancelled")
        m = self.start()
        self.clock += 7.9
        self.get("matches/" + m["id"], self.b)
        self.clock += 0.2
        service.tick()
        self.assertEqual(self.get("matches/" + m["id"], self.b).json()["match"]["state"], "forfeited")

    def test_offscreen_joint_interrupts_tracking_without_wedging_evidence_upload(self):
        m = self.start()
        nonce = next(p["nonce"] for p in m["participants"] if p["isYou"])
        offscreen = pose(0)
        offscreen["joints"]["leftWrist"]["x"] = -0.1
        path = "matches/" + m["id"] + "/evidence"
        response = self.post(path, self.a, dict(nonce=nonce, ruleVersion=VERSION, sequence=0, frames=[offscreen]))
        self.assertEqual(response.status_code, 200, response.text)
        receipt = self.post(path, self.a, dict(nonce=nonce, ruleVersion=VERSION, sequence=1, frames=[pose(0.1)])).json()
        self.assertEqual(receipt["nextSequence"], 2)
        self.assertEqual(receipt["score"], 0)

    def test_evidence_authorization_anti_replay_order_and_time_window(self):
        m = self.start()
        you = next(p for p in m["participants"] if p["isYou"])
        evidence = dict(nonce=you["nonce"], ruleVersion=VERSION, sequence=0, frames=[pose(0)])
        path = "matches/" + m["id"] + "/evidence"
        self.assertEqual(self.post(path, self.b, evidence).status_code, 403)
        r = self.post(path, self.a, evidence)
        self.assertEqual(r.status_code, 200, r.text)
        self.assertEqual(self.post(path, self.a, evidence).json()["nextSequence"], 1)
        altered = copy.deepcopy(evidence); altered["frames"][0]["people"] = 2
        self.assertEqual(self.post(path, self.a, altered).status_code, 409)
        future = dict(evidence, sequence=1, frames=[pose(20)])
        self.assertEqual(self.post(path, self.a, future).status_code, 422)
        final_score = dict(evidence, score=500)
        self.assertEqual(self.post(path, self.a, final_score).status_code, 422)
        c = self.register("outsider")
        self.assertEqual(self.get("matches/" + m["id"], c).status_code, 404)
        self.assertEqual(self.post("matches/" + m["id"] + "/leave", c).status_code, 404)

    def test_insufficient_evidence_never_creates_a_win_or_rating(self):
        m = self.start()
        for i in range(1, 61):
            self.clock = m["startAt"] + i
            self.heartbeat(m["id"])
        for auth in (self.a, self.b): self.post("matches/" + m["id"] + "/submit", auth)
        match = self.get("matches/" + m["id"], self.a).json()["match"]
        self.assertEqual(match["state"], "invalid")
        self.assertIsNone(match["winner"])
        self.assertEqual(self.get("me", self.a).json()["ratings"], [])
        self.assertEqual(self.get("me", self.a).json()["allowances"][0]["remaining"], 9)

    def test_full_evidence_round_finalizes_once_and_persists_after_reopen(self):
        m = self.start()
        nonces = {name: next(p["nonce"] for p in self.get("matches/" + m["id"], auth).json()["match"]["participants"] if p["isYou"]) for name, auth in (("a", self.a), ("b", self.b))}
        sequences = {"a": 0, "b": 0}
        for i in range(-30, 600, 10):
            self.clock = m["startAt"] + max(0, (i + 9) / 10)
            for name, auth in (("a", self.a), ("b", self.b)):
                frames = [pose(j / 10, bottom=name == "a" and 40 <= j < 45) for j in range(i, i + 10)]
                response = self.post("matches/" + m["id"] + "/evidence", auth, dict(nonce=nonces[name], ruleVersion=VERSION, sequence=sequences[name], frames=frames))
                self.assertEqual(response.status_code, 200, response.text)
                sequences[name] = response.json()["nextSequence"]
        self.clock = m["endAt"]
        for auth in (self.a, self.b): self.post("matches/" + m["id"] + "/submit", auth)
        a = self.get("matches/" + m["id"], self.a).json()["match"]
        b = self.get("matches/" + m["id"], self.b).json()["match"]
        self.assertEqual(a["state"], "completed")
        self.assertEqual(a["winner"], b["winner"])
        self.assertEqual(next(p for p in a["participants"] if p["isYou"])["score"], 1)
        for _ in range(3): self.post("matches/" + m["id"] + "/submit", self.a)
        self.client.close()
        service.initialize()
        self.client = TestClient(service.app)
        history = self.get("history", self.a).json()["matches"]
        self.assertEqual([r["id"] for r in history], [m["id"]])
        ratings = self.get("me", self.a).json()["ratings"]
        self.assertEqual(ratings[0]["games"], 1)
        self.assertEqual(ratings[0]["rating"], 1020)

    def test_session_rotation_logout_and_public_privacy(self):
        rotated = self.client.post("/v1/auth/refresh", json=dict(refreshToken=self.a["refreshToken"]))
        self.assertEqual(rotated.status_code, 200)
        self.assertEqual(self.get("me", self.a).status_code, 401)
        self.a = rotated.json()
        identity = self.get("me", self.a).json()["identity"]
        private = self.post("me/privacy", self.a, dict(displayName="Public alias", listed=False))
        self.assertEqual(private.status_code, 200)
        self.assertEqual(self.get("players/" + identity["publicID"], self.b).status_code, 404)
        self.post("auth/logout", self.a)
        self.assertEqual(self.get("me", self.a).status_code, 401)
        self.assertEqual(self.client.post("/v1/auth/refresh", json=dict(refreshToken=self.a["refreshToken"])).status_code, 401)

    def test_advanced_attempts_are_explicitly_unavailable_for_rating(self):
        for variation in ADVANCED:
            response = self.post("queue", self.a, dict(variation=variation, ruleVersion=VERSION, requestID=secrets.token_hex(16)))
            self.assertEqual(response.status_code, 422)
        self.assertIsNone(self.get("state", self.a).json()["queue"])

    def test_leaderboard_order_pagination_and_actual_current_user_jump(self):
        uid = self.uid(self.a)
        with service.transaction() as db:
            db.execute("INSERT INTO ratings VALUES (?,?,?,?,'elo-1')", (uid, "standardPushUp", 1000, 6))
            for i in range(27):
                other = secrets.token_hex(16)
                db.execute("INSERT INTO accounts VALUES (?,?,?,?,?,?,?)", (other, "public-" + str(i), "seed-" + str(i), "fixture-only", "Athlete " + str(i), 1, self.clock))
                db.execute("INSERT INTO ratings VALUES (?,?,?,?,'elo-1')", (other, "standardPushUp", 1500 - i, 6))
        first = self.get("leaderboard/standardPushUp", self.a).json()
        second = self.get("leaderboard/standardPushUp?cursor=" + first["nextCursor"], self.a).json()
        self.assertEqual(len(first["rows"]), 20)
        self.assertEqual(len(second["rows"]), 8)
        self.assertFalse(set(r["publicID"] for r in first["rows"]) & set(r["publicID"] for r in second["rows"]))
        around = self.get("leaderboard/standardPushUp?aroundMe=true", self.a).json()
        self.assertEqual(around["me"]["position"], 28)
        self.assertIn(around["me"]["publicID"], [r["publicID"] for r in around["rows"]])
        self.assertEqual(self.get("leaderboard/widePushUp", self.a).json()["rows"], [])


if __name__ == "__main__":
    unittest.main()
