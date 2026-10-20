use std::{borrow::Cow, fmt, str::FromStr};

use serde::{
    Deserialize, Deserializer, Serialize, Serializer,
    de::{self, MapAccess, Visitor},
    ser::SerializeMap,
};

pub const VERSION: &str = "pose-1";

#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Variation {
    StandardPushUp,
    WidePushUp,
    ClosePushUp,
    KneePushUp,
    PausedPushUp,
    TempoPushUp,
    DiamondPushUp,
    WallHandstandPushUp,
    FreestandingHandstandPushUp,
    PlanchePushUp,
    StandardSquat,
    WideSquat,
    NarrowSquat,
    PausedSquat,
    ForearmPlank,
    HighPlank,
    LeftSidePlank,
    RightSidePlank,
}

pub const VARIATIONS: [Variation; 18] = [
    Variation::StandardPushUp,
    Variation::WidePushUp,
    Variation::ClosePushUp,
    Variation::KneePushUp,
    Variation::PausedPushUp,
    Variation::TempoPushUp,
    Variation::DiamondPushUp,
    Variation::WallHandstandPushUp,
    Variation::FreestandingHandstandPushUp,
    Variation::PlanchePushUp,
    Variation::StandardSquat,
    Variation::WideSquat,
    Variation::NarrowSquat,
    Variation::PausedSquat,
    Variation::ForearmPlank,
    Variation::HighPlank,
    Variation::LeftSidePlank,
    Variation::RightSidePlank,
];

impl Variation {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::StandardPushUp => "standardPushUp",
            Self::WidePushUp => "widePushUp",
            Self::ClosePushUp => "closePushUp",
            Self::KneePushUp => "kneePushUp",
            Self::PausedPushUp => "pausedPushUp",
            Self::TempoPushUp => "tempoPushUp",
            Self::DiamondPushUp => "diamondPushUp",
            Self::WallHandstandPushUp => "wallHandstandPushUp",
            Self::FreestandingHandstandPushUp => "freestandingHandstandPushUp",
            Self::PlanchePushUp => "planchePushUp",
            Self::StandardSquat => "standardSquat",
            Self::WideSquat => "wideSquat",
            Self::NarrowSquat => "narrowSquat",
            Self::PausedSquat => "pausedSquat",
            Self::ForearmPlank => "forearmPlank",
            Self::HighPlank => "highPlank",
            Self::LeftSidePlank => "leftSidePlank",
            Self::RightSidePlank => "rightSidePlank",
        }
    }

    pub const fn family(self) -> &'static str {
        match self {
            Self::StandardSquat | Self::WideSquat | Self::NarrowSquat | Self::PausedSquat => {
                "squats"
            }
            Self::ForearmPlank | Self::HighPlank | Self::LeftSidePlank | Self::RightSidePlank => {
                "core"
            }
            _ => "pushUps",
        }
    }

    pub const fn is_advanced(self) -> bool {
        matches!(
            self,
            Self::DiamondPushUp
                | Self::WallHandstandPushUp
                | Self::FreestandingHandstandPushUp
                | Self::PlanchePushUp
        )
    }

    pub const fn is_core(self) -> bool {
        matches!(
            self,
            Self::ForearmPlank | Self::HighPlank | Self::LeftSidePlank | Self::RightSidePlank
        )
    }
}

impl FromStr for Variation {
    type Err = ();

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        VARIATIONS
            .into_iter()
            .find(|v| v.as_str() == value)
            .ok_or(())
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields, try_from = "JointInput")]
pub struct Joint {
    pub confidence: f64,
    pub x: f64,
    pub y: f64,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct JointInput {
    confidence: f64,
    x: f64,
    y: f64,
}

impl TryFrom<JointInput> for Joint {
    type Error = &'static str;

    fn try_from(input: JointInput) -> Result<Self, Self::Error> {
        let joint = Self {
            confidence: input.confidence,
            x: input.x,
            y: input.y,
        };
        joint.validate()?;
        Ok(joint)
    }
}

impl Joint {
    fn validate(&self) -> Result<(), &'static str> {
        if !self.x.is_finite() || !self.y.is_finite() {
            return Err("Joint coordinates must be finite");
        }
        if !self.confidence.is_finite() || !(0.0..=1.0).contains(&self.confidence) {
            return Err("Joint confidence must be between 0 and 1");
        }
        Ok(())
    }
}

const JOINT_NAMES: [&str; 13] = [
    "leftAnkle",
    "leftElbow",
    "leftHip",
    "leftKnee",
    "leftShoulder",
    "leftWrist",
    "nose",
    "rightAnkle",
    "rightElbow",
    "rightHip",
    "rightKnee",
    "rightShoulder",
    "rightWrist",
];

const LEFT_ANKLE: usize = 0;
const LEFT_ELBOW: usize = 1;
const LEFT_HIP: usize = 2;
const LEFT_KNEE: usize = 3;
const LEFT_SHOULDER: usize = 4;
const LEFT_WRIST: usize = 5;
const RIGHT_ANKLE: usize = 7;
const RIGHT_ELBOW: usize = 8;
const RIGHT_HIP: usize = 9;
const RIGHT_KNEE: usize = 10;
const RIGHT_SHOULDER: usize = 11;
const RIGHT_WRIST: usize = 12;

#[derive(Deserialize)]
#[serde(field_identifier, rename_all = "camelCase")]
#[repr(usize)]
enum JointName {
    LeftAnkle,
    LeftElbow,
    LeftHip,
    LeftKnee,
    LeftShoulder,
    LeftWrist,
    Nose,
    RightAnkle,
    RightElbow,
    RightHip,
    RightKnee,
    RightShoulder,
    RightWrist,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Joints([Option<Joint>; 13]);

impl Joints {
    pub fn get(&self, name: &str) -> Option<&Joint> {
        JOINT_NAMES
            .binary_search(&name)
            .ok()
            .and_then(|i| self.0[i].as_ref())
    }
}

impl Serialize for Joints {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        let mut map = serializer.serialize_map(Some(self.0.iter().flatten().count()))?;
        for (name, joint) in JOINT_NAMES.iter().zip(self.0.iter()) {
            if let Some(joint) = joint {
                map.serialize_entry(name, joint)?;
            }
        }
        map.end()
    }
}

impl<'de> Deserialize<'de> for Joints {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        struct JointsVisitor;

        impl<'de> Visitor<'de> for JointsVisitor {
            type Value = Joints;

            fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
                formatter.write_str("an object containing known body joints")
            }

            fn visit_map<M: MapAccess<'de>>(self, mut map: M) -> Result<Joints, M::Error> {
                let mut joints = Joints::default();
                while let Some(name) = map.next_key::<JointName>()? {
                    let index = name as usize;
                    if joints.0[index].is_some() {
                        return Err(de::Error::duplicate_field(JOINT_NAMES[index]));
                    }
                    joints.0[index] = Some(map.next_value()?);
                }
                Ok(joints)
            }
        }

        deserializer.deserialize_map(JointsVisitor)
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields, try_from = "PoseInput")]
pub struct Pose {
    pub aspect: f64,
    pub camera_moving: bool,
    pub diamond_contact: Option<bool>,
    pub joints: Joints,
    pub light: f64,
    pub people: i64,
    pub time: f64,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct PoseInput {
    aspect: f64,
    camera_moving: bool,
    #[serde(default)]
    diamond_contact: Option<bool>,
    joints: Joints,
    light: f64,
    people: i64,
    time: f64,
}

impl TryFrom<PoseInput> for Pose {
    type Error = &'static str;

    fn try_from(input: PoseInput) -> Result<Self, Self::Error> {
        let pose = Self {
            aspect: input.aspect,
            camera_moving: input.camera_moving,
            diamond_contact: input.diamond_contact,
            joints: input.joints,
            light: input.light,
            people: input.people,
            time: input.time,
        };
        pose.validate()?;
        Ok(pose)
    }
}

impl Pose {
    pub fn validate(&self) -> Result<(), &'static str> {
        if !self.time.is_finite() {
            return Err("Frame time must be finite");
        }
        if !self.aspect.is_finite() || !(0.2..=5.0).contains(&self.aspect) {
            return Err("Aspect must be between 0.2 and 5");
        }
        if !(0..=100).contains(&self.people) {
            return Err("People must be between 0 and 100");
        }
        if !self.light.is_finite() || !(0.0..=1.0).contains(&self.light) {
            return Err("Light must be between 0 and 1");
        }
        for joint in self.joints.0.iter().flatten() {
            joint.validate()?;
        }
        Ok(())
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Assessment {
    pub valid: bool,
    pub top: bool,
    pub bottom: bool,
    pub reason: &'static str,
    pub scale: f64,
}

impl Assessment {
    fn invalid(reason: &'static str) -> Self {
        Self {
            valid: false,
            top: false,
            bottom: false,
            reason,
            scale: 0.0,
        }
    }

    fn valid(variation: Variation, scale: f64, top: bool, bottom: bool) -> Self {
        Self {
            valid: true,
            top,
            bottom,
            reason: if variation.is_core() {
                "Hold your line"
            } else {
                "Complete the full movement"
            },
            scale,
        }
    }
}

#[derive(Clone, Copy, Default)]
struct Point {
    x: f64,
    y: f64,
}

fn distance(a: Point, b: Point) -> f64 {
    (a.x - b.x).hypot(a.y - b.y)
}

fn angle(a: Point, b: Point, c: Point) -> f64 {
    let u = Point {
        x: a.x - b.x,
        y: a.y - b.y,
    };
    let v = Point {
        x: c.x - b.x,
        y: c.y - b.y,
    };
    let length = u.x.hypot(u.y) * v.x.hypot(v.y);
    if length > 0.0001 {
        ((u.x * v.x + u.y * v.y) / length)
            .clamp(-1.0, 1.0)
            .acos()
            .to_degrees()
    } else {
        0.0
    }
}

pub fn assess(pose: &Pose, variation: Variation) -> Assessment {
    if pose.people != 1 {
        return Assessment::invalid(if pose.people == 0 {
            "Step into view"
        } else {
            "One athlete only"
        });
    }
    if pose.light < 0.12 {
        return Assessment::invalid("Find brighter, even light");
    }
    if pose.camera_moving {
        return Assessment::invalid("Keep the camera steady · Recalibrate");
    }
    let mut p = [Point::default(); 13];
    for (point, joint) in p.iter_mut().zip(pose.joints.0.iter()) {
        let Some(joint) = joint else {
            return Assessment::invalid("Keep head, hands and feet visible");
        };
        if joint.confidence < 0.45
            || !(0.025..=0.975).contains(&joint.x)
            || !(0.025..=0.975).contains(&joint.y)
        {
            return Assessment::invalid("Keep head, hands and feet visible");
        }
        *point = Point {
            x: joint.x * pose.aspect,
            y: joint.y,
        };
    }
    let ls = p[LEFT_SHOULDER];
    let rs = p[RIGHT_SHOULDER];
    let lh = p[LEFT_HIP];
    let rh = p[RIGHT_HIP];
    let torso = (distance(ls, lh) + distance(rs, rh)) / 2.0;
    let mut min_x = p[0].x;
    let mut max_x = p[0].x;
    let mut min_y = p[0].y;
    let mut max_y = p[0].y;
    for point in &p[1..] {
        min_x = min_x.min(point.x);
        max_x = max_x.max(point.x);
        min_y = min_y.min(point.y);
        max_y = max_y.max(point.y);
    }
    let extent = ((max_x - min_x) / pose.aspect).max(max_y - min_y);
    if torso <= 0.07 || extent < 0.35 {
        return Assessment::invalid("Move closer · Full body in view");
    }
    let mut elbows = [0.0_f64; 2];
    let mut knees = [0.0_f64; 2];
    let mut hips = [0.0_f64; 2];
    for (i, indices) in [
        [
            LEFT_SHOULDER,
            LEFT_ELBOW,
            LEFT_WRIST,
            LEFT_HIP,
            LEFT_KNEE,
            LEFT_ANKLE,
        ],
        [
            RIGHT_SHOULDER,
            RIGHT_ELBOW,
            RIGHT_WRIST,
            RIGHT_HIP,
            RIGHT_KNEE,
            RIGHT_ANKLE,
        ],
    ]
    .into_iter()
    .enumerate()
    {
        let [s, e, w, h, k, a] = indices.map(|index| p[index]);
        elbows[i] = angle(s, e, w);
        knees[i] = angle(h, k, a);
        hips[i] = angle(
            s,
            h,
            if variation == Variation::KneePushUp {
                k
            } else {
                a
            },
        );
    }
    let shoulder_span = distance(ls, rs);
    let hand_span = distance(p[LEFT_WRIST], p[RIGHT_WRIST]);
    let foot_span = distance(p[LEFT_ANKLE], p[RIGHT_ANKLE]);
    let stance = foot_span / shoulder_span.max(0.001);
    let grip = hand_span / shoulder_span.max(0.001);
    let sy = (ls.y + rs.y) / 2.0;
    let hy = (lh.y + rh.y) / 2.0;
    let ay = (p[LEFT_ANKLE].y + p[RIGHT_ANKLE].y) / 2.0;
    let wy = (p[LEFT_WRIST].y + p[RIGHT_WRIST].y) / 2.0;
    let elbow = elbows[0].min(elbows[1]);
    let knee = knees[0].min(knees[1]);
    let hip = hips[0].min(hips[1]);
    let deepest_elbow = elbows[0].max(elbows[1]);
    let deepest_knee = knees[0].max(knees[1]);

    if variation.family() == "squats" {
        if shoulder_span <= torso * 0.3 {
            return Assessment::invalid("Turn to a three-quarter view · Show both feet");
        }
        let (lo, hi) = match variation {
            Variation::WideSquat => (1.4, 2.8),
            Variation::NarrowSquat => (0.2, 0.85),
            _ => (0.85, 1.5),
        };
        if !(lo..=hi).contains(&stance) {
            return Assessment::invalid("Reset the selected stance");
        }
        if !(sy > hy && hy > ay) {
            return Assessment::invalid("Keep your torso upright");
        }
        let ky = (p[LEFT_KNEE].y + p[RIGHT_KNEE].y) / 2.0;
        return Assessment::valid(
            variation,
            torso,
            knee >= 160.0 && hip >= 155.0,
            deepest_knee <= 100.0 && hy <= ky + torso * 0.15,
        );
    }
    if matches!(
        variation,
        Variation::LeftSidePlank | Variation::RightSidePlank
    ) {
        let (s, e, w, other) = if variation == Variation::LeftSidePlank {
            (ls, p[LEFT_ELBOW], p[LEFT_WRIST], rs)
        } else {
            (rs, p[RIGHT_ELBOW], p[RIGHT_WRIST], ls)
        };
        if !(s.y < other.y - torso * 0.12
            && (ls.x - rs.x).abs() < torso * 0.4
            && foot_span < torso * 0.4
            && (s.x - e.x).abs() < torso * 0.35
            && angle(s, e, w) < 125.0
            && hip >= 160.0
            && knee >= 155.0)
        {
            return Assessment::invalid("Stack shoulders and feet · Support the selected side");
        }
        return Assessment::valid(variation, torso, true, false);
    }
    if matches!(
        variation,
        Variation::WallHandstandPushUp | Variation::FreestandingHandstandPushUp
    ) {
        if !(ay > hy
            && hy > sy
            && sy > wy
            && ((lh.x + rh.x - ls.x - rs.x) / 2.0).abs() < torso * 0.4
            && hip >= 155.0
            && knee >= 155.0)
        {
            return Assessment::invalid("Show a straight, fully inverted body");
        }
    } else {
        if (sy - hy).abs() >= torso * 0.65 || hip < 160.0 {
            return Assessment::invalid("Align shoulders, hips and legs");
        }
        if variation == Variation::KneePushUp {
            let ky = (p[LEFT_KNEE].y + p[RIGHT_KNEE].y) / 2.0;
            if deepest_knee >= 155.0 || (ky - wy).abs() >= torso * 0.4 {
                return Assessment::invalid("Use knee support · Keep hips straight");
            }
        } else {
            if knee < 155.0 {
                return Assessment::invalid("Keep knees extended");
            }
            if variation == Variation::PlanchePushUp {
                if ay <= wy + torso * 0.18 {
                    return Assessment::invalid("Both feet must remain above hand support");
                }
            } else if (ay - wy).abs() >= torso * 0.45 {
                return Assessment::invalid("Keep toes and hands at floor level");
            }
        }
    }
    if matches!(
        variation,
        Variation::WidePushUp
            | Variation::ClosePushUp
            | Variation::DiamondPushUp
            | Variation::StandardPushUp
            | Variation::PausedPushUp
            | Variation::TempoPushUp
    ) {
        if shoulder_span <= torso * 0.3 {
            return Assessment::invalid("Turn slightly · Show both hands and shoulders");
        }
        let (lo, hi) = match variation {
            Variation::WidePushUp => (1.4, 2.8),
            Variation::ClosePushUp => (0.35, 0.85),
            Variation::DiamondPushUp => (0.0, 0.55),
            _ => (0.85, 1.5),
        };
        if !(lo..=hi).contains(&grip) {
            return Assessment::invalid("Reset the selected hand placement");
        }
        if variation == Variation::DiamondPushUp && pose.diamond_contact != Some(true) {
            return Assessment::invalid("Show both thumbs and index fingertips together");
        }
    }
    if variation == Variation::ForearmPlank {
        if !(elbow >= 65.0
            && deepest_elbow <= 115.0
            && (ls.x - p[LEFT_ELBOW].x).abs() < torso * 0.35
            && (rs.x - p[RIGHT_ELBOW].x).abs() < torso * 0.35)
        {
            return Assessment::invalid("Elbows under shoulders · Forearms down");
        }
        return Assessment::valid(variation, torso, true, false);
    }
    if variation == Variation::HighPlank {
        if !(elbow >= 155.0
            && (ls.x - p[LEFT_WRIST].x).abs() < torso * 0.4
            && (rs.x - p[RIGHT_WRIST].x).abs() < torso * 0.4)
        {
            return Assessment::invalid("Straight arms · Hands beneath shoulders");
        }
        return Assessment::valid(variation, torso, true, false);
    }
    Assessment::valid(variation, torso, elbow >= 160.0, deepest_elbow <= 95.0)
}

fn initial_reason() -> Cow<'static, str> {
    Cow::Borrowed("Set position")
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Tracker {
    pub variation: Variation,
    #[serde(default)]
    pub score: f64,
    #[serde(default)]
    pub phase: i64,
    #[serde(default)]
    pub stable: Option<f64>,
    #[serde(default)]
    pub calibration: Option<f64>,
    #[serde(default)]
    pub scale: Option<f64>,
    #[serde(default)]
    pub hold: Option<f64>,
    #[serde(default)]
    pub descending: Option<f64>,
    #[serde(default)]
    pub bottom: Option<f64>,
    #[serde(default)]
    pub last: Option<f64>,
    #[serde(default)]
    pub calibrated: bool,
    #[serde(default)]
    pub valid_seconds: f64,
    #[serde(default)]
    pub covered_seconds: f64,
    #[serde(default)]
    pub last_usable: bool,
    #[serde(default = "initial_reason")]
    pub reason: Cow<'static, str>,
}

impl Tracker {
    pub fn new(variation: Variation) -> Self {
        Self {
            variation,
            score: 0.0,
            phase: 0,
            stable: None,
            calibration: None,
            scale: None,
            hold: None,
            descending: None,
            bottom: None,
            last: None,
            calibrated: false,
            valid_seconds: 0.0,
            covered_seconds: 0.0,
            last_usable: false,
            reason: initial_reason(),
        }
    }

    pub fn reset(&mut self) {
        self.phase = 0;
        self.stable = None;
        self.hold = None;
        self.descending = None;
        self.bottom = None;
    }

    pub fn consume(&mut self, pose: &Pose) -> Result<(), &'static str> {
        pose.validate()?;
        let t = pose.time;
        if self.last.is_some_and(|last| t <= last) {
            return Err("Frame timestamps must increase");
        }
        let gap = self.last.map_or(0.0, |last| t - last);
        self.last = Some(t);
        let a = assess(pose, self.variation);
        if (0.0..=60.0).contains(&t) && gap > 0.0 && gap <= 0.25 {
            self.covered_seconds += gap.min(t);
            if a.valid && self.last_usable {
                self.valid_seconds += gap.min(t);
            }
        }
        self.last_usable = a.valid;
        if gap > 0.25
            || !a.valid
            || self
                .scale
                .is_some_and(|scale| (a.scale / scale - 1.0).abs() > 0.22)
        {
            self.reset();
            self.calibration = None;
            self.scale = None;
            self.calibrated = false;
            self.reason = Cow::Borrowed(a.reason);
            return Ok(());
        }
        if !self.calibrated {
            if a.top {
                let calibration = *self.calibration.get_or_insert(t);
                if t - calibration >= 1.5 {
                    self.calibrated = true;
                    self.scale = Some(a.scale);
                }
            } else {
                self.calibration = None;
            }
        }
        if !(0.0..=60.0).contains(&t) {
            self.reset();
            return Ok(());
        }
        if !self.calibrated {
            self.reset();
            return Ok(());
        }
        if self.variation.is_core() {
            let hold = *self.hold.get_or_insert(t);
            self.score = self.score.max(t - hold);
        } else if self.phase == 0 {
            if a.top {
                let stable = *self.stable.get_or_insert(t);
                if t - stable >= 0.18 {
                    self.phase = 1;
                    self.stable = None;
                }
            } else {
                self.stable = None;
            }
        } else if self.phase == 1 {
            if !a.top && self.descending.is_none() {
                self.descending = Some(t);
            }
            if a.bottom {
                let bottom = *self.bottom.get_or_insert(t);
                let pause = if matches!(
                    self.variation,
                    Variation::PausedPushUp | Variation::PausedSquat
                ) {
                    1.0
                } else {
                    0.18
                };
                if t - bottom >= pause {
                    self.phase = 2;
                    self.stable = None;
                }
            } else {
                self.bottom = None;
                if a.top {
                    self.descending = None;
                }
            }
        } else if a.top {
            let stable = *self.stable.get_or_insert(t);
            if t - stable >= 0.18 {
                let descent = self.bottom.unwrap_or(t) - self.descending.unwrap_or(t);
                if self.variation != Variation::TempoPushUp || descent >= 3.0 {
                    self.score += 1.0;
                }
                self.phase = 1;
                self.stable = None;
                self.bottom = None;
                self.descending = None;
            }
        } else {
            self.stable = None;
        }
        Ok(())
    }
}

pub fn elo(a: i64, b: i64, result: f64, games_a: i64, games_b: i64) -> (i64, i64) {
    let expected = 1.0 / (1.0 + 10.0_f64.powf((b as f64 - a as f64) / 400.0));
    let ka = if games_a < 5 { 40.0 } else { 24.0 };
    let kb = if games_b < 5 { 40.0 } else { 24.0 };
    (
        a.saturating_add((ka * (result - expected)).round() as i64)
            .clamp(0, 5000),
        b.saturating_add((kb * (expected - result)).round() as i64)
            .clamp(0, 5000),
    )
}
