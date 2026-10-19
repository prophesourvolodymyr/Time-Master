import math
from dataclasses import dataclass, field, asdict

VERSION = "pose-1"
PUSH_UPS = ["standardPushUp", "widePushUp", "closePushUp", "kneePushUp", "pausedPushUp", "tempoPushUp", "diamondPushUp", "wallHandstandPushUp", "freestandingHandstandPushUp", "planchePushUp"]
SQUATS = ["standardSquat", "wideSquat", "narrowSquat", "pausedSquat"]
CORE = ["forearmPlank", "highPlank", "leftSidePlank", "rightSidePlank"]
ADVANCED = set(PUSH_UPS[6:])
VARIATIONS = PUSH_UPS + SQUATS + CORE
JOINTS = ["nose"] + [side + joint for side in ("left", "right") for joint in ("Shoulder", "Elbow", "Wrist", "Hip", "Knee", "Ankle")]


def family(variation):
    return "pushUps" if variation in PUSH_UPS else "squats" if variation in SQUATS else "core"


def angle(a, b, c):
    u, v = (a[0] - b[0], a[1] - b[1]), (c[0] - b[0], c[1] - b[1])
    length = math.hypot(*u) * math.hypot(*v)
    return math.degrees(math.acos(max(-1, min(1, (u[0] * v[0] + u[1] * v[1]) / length)))) if length > 0.0001 else 0


def distance(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def assess(pose, variation):
    def invalid(reason):
        return dict(valid=False, top=False, bottom=False, reason=reason, scale=0)

    if pose["people"] != 1:
        return invalid("Step into view" if pose["people"] == 0 else "One athlete only")
    if pose["light"] < 0.12:
        return invalid("Find brighter, even light")
    if pose["cameraMoving"]:
        return invalid("Keep the camera steady · Recalibrate")
    points = pose["joints"]
    if any(n not in points or points[n]["confidence"] < 0.45 or not 0.025 <= points[n]["x"] <= 0.975 or not 0.025 <= points[n]["y"] <= 0.975 for n in JOINTS):
        return invalid("Keep head, hands and feet visible")
    p = {n: (points[n]["x"] * pose["aspect"], points[n]["y"]) for n in JOINTS}
    ls, rs, lh, rh = [p[n] for n in ("leftShoulder", "rightShoulder", "leftHip", "rightHip")]
    torso = (distance(ls, lh) + distance(rs, rh)) / 2
    extent = max((max(q[0] for q in p.values()) - min(q[0] for q in p.values())) / pose["aspect"], max(q[1] for q in p.values()) - min(q[1] for q in p.values()))
    if torso <= 0.07 or extent < 0.35:
        return invalid("Move closer · Full body in view")
    elbows, knees, hips = [], [], []
    for side in ("left", "right"):
        s, e, w, h, k, a = [p[side + n] for n in ("Shoulder", "Elbow", "Wrist", "Hip", "Knee", "Ankle")]
        elbows.append(angle(s, e, w))
        knees.append(angle(h, k, a))
        hips.append(angle(s, h, k if variation == "kneePushUp" else a))
    shoulder_span = distance(ls, rs)
    hand_span = distance(p["leftWrist"], p["rightWrist"])
    foot_span = distance(p["leftAnkle"], p["rightAnkle"])
    stance, grip = foot_span / max(shoulder_span, 0.001), hand_span / max(shoulder_span, 0.001)
    sy, hy = (ls[1] + rs[1]) / 2, (lh[1] + rh[1]) / 2
    ay = (p["leftAnkle"][1] + p["rightAnkle"][1]) / 2
    wy = (p["leftWrist"][1] + p["rightWrist"][1]) / 2
    elbow, knee, hip = min(elbows), min(knees), min(hips)
    deepest_elbow, deepest_knee = max(elbows), max(knees)

    def valid(top=True, bottom=False):
        return dict(valid=True, top=top, bottom=bottom, reason="Hold your line" if variation in CORE else "Complete the full movement", scale=torso)

    if variation in SQUATS:
        if shoulder_span <= torso * 0.3:
            return invalid("Turn to a three-quarter view · Show both feet")
        lo, hi = (1.4, 2.8) if variation == "wideSquat" else (0.2, 0.85) if variation == "narrowSquat" else (0.85, 1.5)
        if not lo <= stance <= hi:
            return invalid("Reset the selected stance")
        if not sy > hy > ay:
            return invalid("Keep your torso upright")
        ky = (p["leftKnee"][1] + p["rightKnee"][1]) / 2
        return valid(knee >= 160 and hip >= 155, deepest_knee <= 100 and hy <= ky + torso * 0.15)
    if variation in ("leftSidePlank", "rightSidePlank"):
        side = "left" if variation == "leftSidePlank" else "right"
        other = "right" if side == "left" else "left"
        s, e, w = [p[side + n] for n in ("Shoulder", "Elbow", "Wrist")]
        if not (s[1] < p[other + "Shoulder"][1] - torso * 0.12 and abs(ls[0] - rs[0]) < torso * 0.4 and foot_span < torso * 0.4 and abs(s[0] - e[0]) < torso * 0.35 and angle(s, e, w) < 125 and hip >= 160 and knee >= 155):
            return invalid("Stack shoulders and feet · Support the selected side")
        return valid()
    if variation in ("wallHandstandPushUp", "freestandingHandstandPushUp"):
        if not (ay > hy > sy > wy and abs((lh[0] + rh[0] - ls[0] - rs[0]) / 2) < torso * 0.4 and hip >= 155 and knee >= 155):
            return invalid("Show a straight, fully inverted body")
    else:
        if abs(sy - hy) >= torso * 0.65 or hip < 160:
            return invalid("Align shoulders, hips and legs")
        if variation == "kneePushUp":
            ky = (p["leftKnee"][1] + p["rightKnee"][1]) / 2
            if deepest_knee >= 155 or abs(ky - wy) >= torso * 0.4:
                return invalid("Use knee support · Keep hips straight")
        else:
            if knee < 155:
                return invalid("Keep knees extended")
            if variation == "planchePushUp":
                if ay <= wy + torso * 0.18:
                    return invalid("Both feet must remain above hand support")
            elif abs(ay - wy) >= torso * 0.45:
                return invalid("Keep toes and hands at floor level")
    if variation in ("widePushUp", "closePushUp", "diamondPushUp", "standardPushUp", "pausedPushUp", "tempoPushUp"):
        if shoulder_span <= torso * 0.3:
            return invalid("Turn slightly · Show both hands and shoulders")
        lo, hi = (1.4, 2.8) if variation == "widePushUp" else (0.35, 0.85) if variation == "closePushUp" else (0, 0.55) if variation == "diamondPushUp" else (0.85, 1.5)
        if not lo <= grip <= hi:
            return invalid("Reset the selected hand placement")
        if variation == "diamondPushUp" and pose.get("diamondContact") is not True:
            return invalid("Show both thumbs and index fingertips together")
    if variation == "forearmPlank":
        if not (65 <= elbow and deepest_elbow <= 115 and abs(ls[0] - p["leftElbow"][0]) < torso * 0.35 and abs(rs[0] - p["rightElbow"][0]) < torso * 0.35):
            return invalid("Elbows under shoulders · Forearms down")
        return valid()
    if variation == "highPlank":
        if not (elbow >= 155 and abs(ls[0] - p["leftWrist"][0]) < torso * 0.4 and abs(rs[0] - p["rightWrist"][0]) < torso * 0.4):
            return invalid("Straight arms · Hands beneath shoulders")
        return valid()
    return valid(elbow >= 160, deepest_elbow <= 95)


@dataclass
class Tracker:
    variation: str
    score: float = 0
    phase: int = 0
    stable: float | None = None
    calibration: float | None = None
    scale: float | None = None
    hold: float | None = None
    descending: float | None = None
    bottom: float | None = None
    last: float | None = None
    calibrated: bool = False
    valid_seconds: float = 0
    covered_seconds: float = 0
    last_usable: bool = False
    reason: str = "Set position"

    def reset(self):
        self.phase = 0
        self.stable = self.hold = self.descending = self.bottom = None

    def consume(self, pose):
        t = pose["time"]
        if self.last is not None and t <= self.last:
            raise ValueError("Frame timestamps must increase")
        gap = t - self.last if self.last is not None else 0
        self.last = t
        a = assess(pose, self.variation)
        if 0 <= t <= 60 and 0 < gap <= 0.25:
            self.covered_seconds += min(gap, t)
            if a["valid"] and self.last_usable:
                self.valid_seconds += min(gap, t)
        self.last_usable = a["valid"]
        if gap > 0.25 or not a["valid"] or (self.scale is not None and abs(a["scale"] / self.scale - 1) > 0.22):
            self.reset()
            self.calibration = self.scale = None
            self.calibrated = False
            self.reason = a["reason"]
            return
        if not self.calibrated:
            if a["top"]:
                if self.calibration is None:
                    self.calibration = t
                if t - self.calibration >= 1.5:
                    self.calibrated, self.scale = True, a["scale"]
            else:
                self.calibration = None
        if t < 0 or t > 60:
            self.reset()
            return
        if not self.calibrated:
            self.reset()
            return
        if self.variation in CORE:
            if self.hold is None:
                self.hold = t
            self.score = max(self.score, t - self.hold)
        elif self.phase == 0:
            if a["top"]:
                if self.stable is None:
                    self.stable = t
                if t - self.stable >= 0.18:
                    self.phase, self.stable = 1, None
            else:
                self.stable = None
        elif self.phase == 1:
            if not a["top"] and self.descending is None:
                self.descending = t
            if a["bottom"]:
                if self.bottom is None:
                    self.bottom = t
                pause = 1 if self.variation in ("pausedPushUp", "pausedSquat") else 0.18
                if t - self.bottom >= pause:
                    self.phase, self.stable = 2, None
            else:
                self.bottom = None
                if a["top"]:
                    self.descending = None
        else:
            if a["top"]:
                if self.stable is None:
                    self.stable = t
                if t - self.stable >= 0.18:
                    descent = (self.bottom if self.bottom is not None else t) - (self.descending if self.descending is not None else t)
                    if self.variation != "tempoPushUp" or descent >= 3:
                        self.score += 1
                    self.phase = 1
                    self.stable = self.bottom = self.descending = None
            else:
                self.stable = None

    def snapshot(self):
        return asdict(self)


def elo(a, b, result, games_a, games_b):
    expected = 1 / (1 + 10 ** ((b - a) / 400))
    ka, kb = (40 if games_a < 5 else 24), (40 if games_b < 5 else 24)
    round_away = lambda n: math.floor(n + 0.5) if n >= 0 else math.ceil(n - 0.5)
    return max(0, min(5000, a + round_away(ka * (result - expected)))), max(0, min(5000, b + round_away(kb * (expected - result))))
