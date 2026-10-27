// Builds the complete demo data set relative to `now`, so "today", streaks and the schedule stay current.
import { readFileSync } from "node:fs";
import { EXERCISES, GROUPS, PLANS, TYPES, WORKOUTS, groupId, pageId, workoutId, workoutSeconds } from "./library.mjs";
import {
  addDays, addSeconds, atMinute, dayKey, distanceMeters, iso, isoMilliseconds, mondayOf, random,
  referenceSeconds, resample, startOfDay, uuid, weekday,
} from "./util.mjs";

const ROUTES = JSON.parse(readFileSync(new URL("./routes.json", import.meta.url), "utf8"));
const workoutByKey = Object.fromEntries(WORKOUTS.map((workout) => [workout.key, workout]));
const exerciseByKey = Object.fromEntries(EXERCISES.map((exercise) => [exercise.key, exercise]));
const CHALLENGE_DAYS = [1, 3, 5];

export const NAVIGATION_ORDER = ["coach", "profile", "home", "map", "ranked", "physique", "workouts", "schedule", "database", "analytics", "settings"];

/** The path the simulated runner follows while a scene records a live outdoor workout. */
export const LIVE_RUN = ROUTES.liveRun.coordinates;

function buildPages(now) {
  const created = addDays(startOfDay(now), -150);
  const pages = [];
  GROUPS.forEach((group, groupIndex) => {
    const children = EXERCISES.filter((exercise) => exercise.group === group.key);
    const stamp = iso(addDays(created, groupIndex * 3));
    pages.push({
      path: [groupId(group.key)],
      files: [{ name: "cover.jpg", asset: `group-${group.key}.jpg` }],
      guide: `# ${group.title}\n\n${group.body}\n`,
      manifest: {
        id: groupId(group.key), title: group.title, pageKind: "container", workoutType: TYPES[group.type],
        coverImageFilename: "cover.jpg", markdownBody: group.body, mediaFilenames: [], mediaComments: {},
        linkURLs: [], linkMetadata: [], dropSetTemplates: [], childIDs: children.map((child) => pageId(child.key)),
        order: groupIndex, createdAt: stamp, updatedAt: stamp,
      },
    });
    children.forEach((exercise, index) => {
      const art = exercise.art === null ? null : exercise.art ?? exercise.key;
      const media = art ? `${exercise.key}.jpg` : null;
      const childStamp = iso(addDays(created, groupIndex * 3 + 1 + index));
      pages.push({
        path: [groupId(group.key), pageId(exercise.key)],
        files: media ? [{ name: `media/${media}`, asset: `exercise-${art}.jpg` }] : [],
        guide: `# ${exercise.title}\n\n${exercise.body}\n`,
        manifest: {
          id: pageId(exercise.key), title: exercise.title, pageKind: "leaf", pageType: "exercise", parentID: groupId(group.key),
          markdownBody: exercise.body, mediaFilenames: media ? [media] : [], mediaComments: media && exercise.comment ? { [media]: exercise.comment } : {},
          linkURLs: [], linkMetadata: [], duration: exercise.duration, restAfter: exercise.rest, prepareTime: 4, sets: exercise.sets,
          restBetweenSets: exercise.rest, dropSetTemplates: [], childIDs: [], order: index, createdAt: childStamp, updatedAt: childStamp,
        },
      });
    });
  });
  return pages;
}

/** Player and workout-card art: the square illustration in Documents/Photos (none for recovery moves). */
function sectionMedia(key) {
  const exercise = exerciseByKey[key];
  const art = exercise.art === null ? null : exercise.art ?? exercise.key;
  return art ? [`square-${art}.jpg`] : [];
}

function buildWorkouts(now) {
  const created = addDays(startOfDay(now), -120);
  return WORKOUTS.map((workout, index) => ({
    id: workoutId(workout.key),
    name: workout.name,
    type: TYPES[workout.type],
    colorHex: TYPES[workout.type].colorHex,
    createdAt: iso(addDays(created, index * 5)),
    prepareTime: workout.prepare,
    restBetweenSections: workout.restBetweenSections,
    coverStyle: workout.cover ? "customImage" : "exerciseThumbnails",
    ...(workout.cover ? { imageFilename: `cover-${workout.cover}.jpg` } : {}),
    musicTrackFilenames: [],
    sections: workout.sections.map(([key, set], sectionIndex) => ({
      id: uuid(`section:${workout.key}:${sectionIndex}`),
      exerciseID: pageId(key),
      name: exerciseByKey[key].title,
      duration: set.duration,
      sets: set.sets,
      ...(set.reps ? { repCount: set.reps } : {}),
      restBetweenSets: set.rest,
      prepareTime: 4,
      isTimerEnabled: true,
      mediaFilenames: sectionMedia(key),
      mode: "timed",
      slots: [],
      bundleOrder: "ordered",
      bundleVoiceEnabled: true,
    })),
  }));
}

function planEntry(plan, entry, index) {
  const workout = workoutByKey[entry.workout];
  const type = TYPES[workout.type];
  return {
    id: uuid(`plan:${plan.key}:${index}`), workoutID: workoutId(workout.key), title: workout.name, weekday: entry.weekday,
    startMinute: entry.start, durationSeconds: workoutSeconds(workout), exerciseCount: workout.sections.length, notes: "",
    icon: type.iconName, colorHex: type.colorHex,
  };
}

const planSnapshot = (plan) => ({ id: uuid(`plan:${plan.key}`), name: plan.name, icon: plan.icon, entries: plan.entries.map((entry, index) => planEntry(plan, entry, index)) });

/** Plan start: the Monday seven weeks back, so the schedule shows a running week streak. */
const planStartFor = (now) => mondayOf(addDays(startOfDay(now), -49));

function historyEntry(day, workout, endsAt, rng, { partial = false, index = 0 } = {}) {
  const full = workoutSeconds(workout);
  const completed = partial ? Math.round(full * (0.45 + rng() * 0.2)) : Math.round(full * (0.97 + rng() * 0.06));
  return {
    id: uuid(`history:${dayKey(day)}:${index}`), workoutId: workoutId(workout.key), workoutName: workout.name,
    completedAt: iso(endsAt), durationCompleted: completed, workoutType: TYPES[workout.type], isPartial: partial,
    elapsedSeconds: completed + Math.round(20 + rng() * 120),
  };
}

function buildHistory(now, rng) {
  const today = startOfDay(now);
  const planStart = planStartFor(now);
  const hybrid = PLANS[0];
  const shiftOffChallenge = (day) => (CHALLENGE_DAYS.includes(weekday(day)) ? addDays(day, -1) : day);
  const misses = new Set([dayKey(shiftOffChallenge(addDays(today, -25))), dayKey(addDays(today, -57))]);
  const denseFrom = addDays(today, -56);
  const entries = [];
  for (let offset = -168; offset <= 0; offset += 1) {
    const day = addDays(today, offset);
    if (misses.has(dayKey(day))) continue;
    const planned = hybrid.entries.filter((entry) => entry.weekday === weekday(day));
    if (day >= denseFrom) {
      planned.forEach((entry, index) => {
        const workout = workoutByKey[entry.workout];
        const endsAt = addSeconds(atMinute(day, entry.start), workoutSeconds(workout) + Math.round(rng() * 240));
        if (endsAt < addSeconds(now, -600)) entries.push(historyEntry(day, workout, endsAt, rng, { index }));
      });
      continue;
    }
    const chance = 0.38 + 0.22 * ((offset + 168) / 112);
    if (rng() > chance) continue;
    const entry = planned[0];
    const workout = workoutByKey[entry.workout];
    const endsAt = addSeconds(atMinute(day, entry.start + Math.round((rng() - 0.5) * 60)), workoutSeconds(workout));
    entries.push(historyEntry(day, workout, endsAt, rng, { partial: rng() < 0.07 }));
  }
  if (!entries.some((entry) => new Date(entry.completedAt) >= today)) {
    const mobility = workoutByKey.mobility;
    entries.push(historyEntry(today, mobility, addSeconds(now, -900), rng, { index: 9 }));
  }
  return entries.sort((a, b) => a.completedAt.localeCompare(b.completedAt));
}

function buildConfig(now) {
  const planStart = planStartFor(now);
  const week = dayKey(planStart);
  return {
    customWorkoutTypes: [],
    weeklyGoal: 5,
    restDays: [],
    trainingDays: [1, 2, 3, 4, 5, 6, 7],
    trainingStartDate: iso(planStart),
    trainingDurationMonths: 3,
    typeSchedules: [],
    outdoorRecording: {
      unitSystem: "metric", autoPause: false, keepScreenAwake: true, gpsAccuracy: "precise",
      elevationSource: "gps", audioCues: "off", exportFormat: "gpx",
    },
    workoutSchedule: {
      plans: PLANS.map(planSnapshot),
      selections: [{ week, plan: planSnapshot(PLANS[0]) }],
      additions: {},
      removals: {},
      completions: {},
      challenges: [{ week, weekdays: CHALLENGE_DAYS }],
      startedOn: week,
    },
  };
}

const OUTINGS = [
  { daysAgo: 1, route: "stanleyPark", kind: "run", start: 18 * 60 + 10, title: "Stanley Park Seawall Loop", starred: true, tags: ["seawall", "long run"] },
  { daysAgo: 3, route: "coalHarbour", kind: "walk", start: 12 * 60 + 30, title: "Coal Harbour Lunch Walk", tags: ["recovery"] },
  { daysAgo: 5, route: "falseCreek", kind: "run", start: 18 * 60 + 20, title: "False Creek 10K", tags: ["tempo"] },
  { daysAgo: 8, route: "seawallRide", kind: "bike", start: 8 * 60 + 30, title: "Seawall Ride", starred: true, tags: ["weekend"] },
  { daysAgo: 10, route: "kitsJericho", kind: "run", start: 7 * 60 + 10, title: "Kits to Jericho", tags: ["beach"] },
  { daysAgo: 12, route: "coalHarbour", kind: "walk", start: 19 * 60, title: "Coal Harbour Sunset Walk", tags: ["sunset"] },
  { daysAgo: 15, route: "stanleyPark", kind: "run", start: 18 * 60, title: "Stanley Park Seawall Loop", tags: ["seawall"] },
  { daysAgo: 17, route: "falseCreek", kind: "run", start: 18 * 60 + 30, title: "False Creek 10K", tags: ["tempo"] },
  { daysAgo: 22, route: "seawallRide", kind: "bike", start: 9 * 60, title: "Seawall Ride", tags: ["weekend"] },
  { daysAgo: 24, route: "kitsJericho", kind: "run", start: 7 * 60, title: "Kits to Jericho", tags: ["beach"] },
  { daysAgo: 29, route: "stanleyPark", kind: "run", start: 17 * 60 + 50, title: "Stanley Park Seawall Loop", tags: ["seawall"] },
  { daysAgo: 36, route: "falseCreek", kind: "run", start: 18 * 60 + 15, title: "False Creek 10K", tags: ["tempo"] },
  { daysAgo: 43, route: "seawallRide", kind: "bike", start: 8 * 60 + 40, title: "Seawall Ride", tags: ["weekend"] },
];

const BASE_SPEED = { run: 3.15, walk: 1.4, bike: 6.1 };

function buildActivity(outing, now, rng) {
  const spacing = outing.kind === "bike" ? 14 : 9;
  const coordinates = resample(ROUTES[outing.route].coordinates, spacing);
  const pace = BASE_SPEED[outing.kind] * (0.95 + rng() * 0.1);
  const startedAt = atMinute(addDays(startOfDay(now), -outing.daysAgo), outing.start);
  let time = startedAt;
  let distance = 0;
  let maxSpeed = 0;
  let gain = 0;
  let highest = 0;
  let previousElevation;
  let nextLap = 1000;
  const laps = [];
  const track = coordinates.map((point, index) => {
    let speed = pace;
    if (index > 0) {
      const segment = distanceMeters(coordinates[index - 1], point);
      speed = pace * (0.9 + 0.2 * (0.5 + 0.5 * Math.sin(index / 23)) + (rng() - 0.5) * 0.06);
      time = addSeconds(time, segment / speed);
      distance += segment;
      maxSpeed = Math.max(maxSpeed, speed);
    }
    const elevation = Math.max(1, 6 + 5 * Math.sin(index / 61) + 2.5 * Math.sin(index / 17));
    if (previousElevation !== undefined && elevation > previousElevation) gain += elevation - previousElevation;
    previousElevation = elevation;
    highest = Math.max(highest, elevation);
    if (distance >= nextLap) {
      laps.push({ id: uuid(`lap:${outing.daysAgo}:${laps.length}`), number: laps.length + 1, timestamp: iso(time), elapsedSeconds: Math.round((time - startedAt) / 1000), distanceMeters: nextLap });
      nextLap += 1000;
    }
    return {
      timestamp: isoMilliseconds(time), latitude: Number(point[0].toFixed(6)), longitude: Number(point[1].toFixed(6)),
      elevationMeters: Number(elevation.toFixed(1)), horizontalAccuracyMeters: 4 + Math.round(rng() * 3),
      speedMetersPerSecond: Number(speed.toFixed(2)), state: "recording",
    };
  });
  const seconds = Math.round((time - startedAt) / 1000);
  const id = uuid(`activity:${outing.daysAgo}:${outing.route}`);
  return {
    track,
    manifest: {
      id, schemaVersion: 4, kind: outing.kind, title: outing.title, startedAt: iso(startedAt), endedAt: iso(time),
      elapsedSeconds: seconds, movingSeconds: seconds, distanceMeters: Number(distance.toFixed(1)), totalDistanceMeters: Number(distance.toFixed(1)),
      averageSpeedMetersPerSecond: Number((distance / seconds).toFixed(3)), maxSpeedMetersPerSecond: Number(maxSpeed.toFixed(2)),
      averagePaceSecondsPerKilometer: Number((seconds / (distance / 1000)).toFixed(1)), elevationGainMeters: Math.round(gain),
      highestElevationMeters: Math.round(highest), pauseIntervals: [], laps, trackPointCount: track.length,
      recordingState: "finished", finished: true, establishedAt: iso(addSeconds(time, 75)), visibility: "private",
      starred: Boolean(outing.starred), publicDescription: "", tags: outing.tags, allowComments: true, hideStartFinish: true,
      endpointPrivacyMeters: 200, showPlayerTracks: true, hasPublicMetadata: false, playedTracks: [],
    },
  };
}

const PLANNED = [
  { key: "stanleyPark", title: "Stanley Park Seawall Loop", daysAgo: 40, starred: true },
  { key: "falseCreek", title: "False Creek 10K", daysAgo: 33 },
  { key: "seawallRide", title: "Seawall to Science World Ride", daysAgo: 26 },
  { key: "kitsJericho", title: "Kits Beach to Jericho", daysAgo: 19 },
];

function buildPlannedRoutes(now) {
  return PLANNED.map((route) => {
    const createdAt = atMinute(addDays(startOfDay(now), -route.daysAgo), 20 * 60);
    return {
      id: uuid(`route:${route.key}`), title: route.title, source: "manual", createdAt: iso(createdAt), starred: Boolean(route.starred),
      points: resample(ROUTES[route.key].coordinates, 25).map(([latitude, longitude], index) => ({
        timestamp: iso(addSeconds(createdAt, index)), latitude: Number(latitude.toFixed(6)), longitude: Number(longitude.toFixed(6)),
        horizontalAccuracyMeters: 0, state: "recording",
      })),
    };
  });
}

const PRACTICE = [
  ["standardPushUp", 2, 42], ["standardPushUp", 6, 38], ["standardPushUp", 13, 35], ["widePushUp", 4, 33],
  ["diamondPushUp", 9, 24], ["closePushUp", 11, 29], ["standardSquat", 3, 51], ["pausedSquat", 8, 17],
  ["wideSquat", 12, 44], ["forearmPlank", 5, 60], ["highPlank", 10, 60], ["leftSidePlank", 14, 41.5],
];

function buildPractice(now) {
  return PRACTICE.map(([variation, daysAgo, score], index) => ({
    id: uuid(`practice:${index}`), accountID: null, variation,
    startedAt: referenceSeconds(atMinute(addDays(startOfDay(now), -daysAgo), 7 * 60 + 40 + index)),
    duration: 60, score, status: "completed", ruleVersion: "pose-1",
  }));
}

function currentStreak(history, now) {
  const days = new Set(history.map((entry) => dayKey(new Date(entry.completedAt))));
  let streak = 0;
  for (let day = startOfDay(now); days.has(dayKey(day)); day = addDays(day, -1)) streak += 1;
  return streak;
}

function buildProfile(now, streak) {
  const day = (daysAgo, minute) => iso(atMinute(addDays(startOfDay(now), -daysAgo), minute));
  const post = (key, body, daysAgo, minute, reactions, replies = []) => ({
    id: uuid(`post:${key}`), body, createdAt: day(daysAgo, minute), audience: "profile", allowsReplies: true, reactions,
    replies: replies.map(([text, offset], index) => ({ id: uuid(`reply:${key}:${index}`), body: text, createdAt: day(daysAgo, minute + offset) })),
  });
  const posts = [
    post("streak", `${streak} days straight. The marble does not crack.`, 0, 8 * 60 + 5, ["🔥", "💪"], [["Unreal consistency.", 40], ["Leg day tomorrow, no excuses.", 95]]),
    post("practice", "New personal best in Ranked Practice: 42 push-ups in 60 seconds.", 2, 8 * 60, ["🔥", "🏆"], [["Diamond next?", 30]]),
    post("seawall", "Stanley Park seawall at golden hour. 11.8 km of pure therapy.", 1, 19 * 60 + 40, ["❤️", "🌅"]),
    post("builder", "Built a new Push Day Ladder from my exercise library in two minutes flat.", 9, 20 * 60 + 15, ["⚡️"]),
  ];
  return {
    version: 1,
    profile: {
      id: uuid("profile"), createdAt: day(210, 9 * 60), displayName: "Talos", handle: "talos.tmax", location: "Vancouver, BC",
      biography: "Carved from marble, built by push-ups. Sunrise seawall runs, zero skipped leg days.",
      avatarFilename: "profile-avatar.jpg", bannerFilename: "profile-banner.jpg",
      links: [{ id: uuid("link:instagram"), title: "Instagram", url: "https://instagram.com/tmax.app" }],
      isPrivate: false, showPostsToVisitors: true, showActivityToVisitors: true, showRepostsToVisitors: true,
      showAchievements: true, showLinks: true, allowReplies: true,
    },
    posts,
    repostedIDs: [uuid("post:practice")],
    cosmeticSelections: { avatar: "timemaster-avatar-2", name: "timemaster-name-2", badge: "timemaster-badge-2", entrance: "timemaster-entrance-2" },
    savedCollectibleIDs: ["timemaster-avatar-0", "timemaster-name-1", "timemaster-badge-1", "timemaster-entrance-0", "s0-avatar", "s0-badge"],
    badgePreview: "gold",
    earnedMilestoneClaimed: false,
    reportDrafts: [],
  };
}

function homeLayout() {
  const configuration = (kind, overrides = {}) => ({
    showTypeIcon: kind !== "greeting", showDetails: kind !== "greeting", showStatus: true, showScheduledTime: true,
    visibleCount: kind === "today" ? 4 : 3, activityShortcuts: ["workout", "runWalk", "walk", "bike"],
    metricFields: ["sessions", "streak", "activeMinutes"], ...overrides,
  });
  const widget = (kind, footprint) => ({ id: uuid(`widget:${kind}`), kind, footprint, configuration: configuration(kind) });
  return [
    widget("greeting", "wide"), widget("today", "wide"), widget("streak", "compact"), widget("lifetimeStats", "compact"),
    widget("quickStart", "wide"), widget("activityShortcuts", "wide"), widget("weeklyRhythm", "wide"), widget("outdoorMap", "wide"),
    widget("activityHeatmap", "wide"), widget("recentWorkouts", "wide"), widget("savedRoutes", "wide"), widget("metrics", "wide"),
  ];
}

const json = (value) => ({ data: Buffer.from(JSON.stringify(value)) });

/** Local tracks: quiet tones synthesized by seed.mjs (clips are silent), shown with the app's SF Symbol artwork. */
export const MUSIC_TRACKS = [
  { key: "sunrise", title: "Seawall Sunrise", seconds: 214, tone: 196, symbol: "sunrise.fill" },
  { key: "tempo", title: "Iron Tempo", seconds: 187, tone: 220, symbol: "dumbbell.fill" },
  { key: "lastSet", title: "Last Set Standing", seconds: 243, tone: 247, symbol: "flame.fill" },
  { key: "marble", title: "Marble Mind", seconds: 201, tone: 165, symbol: "brain.head.profile" },
  { key: "nightRun", title: "Night Run 160", seconds: 236, tone: 262, symbol: "figure.run" },
  { key: "tide", title: "Cooldown Tide", seconds: 258, tone: 147, symbol: "water.waves" },
];
export const musicFilename = (track) => `${uuid(`music-file:${track.key}`).slice(0, 8)}_${track.title}.m4a`;

function buildMusic() {
  const local = (track) => ({ filename: musicFilename(track), displayName: track.title, duration: track.seconds });
  const single = (track) => ({
    id: uuid(`music:${track.key}`), name: track.title, kind: "track", source: { kind: "local" }, localReference: local(track),
    artwork: { placeholderSystemImage: track.symbol }, duration: track.seconds, tracks: [], metadata: { artist: "Tmax Sessions" },
  });
  const playlist = (key, name, symbol, keys) => {
    const tracks = keys.map((trackKey) => MUSIC_TRACKS.find((track) => track.key === trackKey));
    return {
      id: uuid(`music:${key}`), name, kind: "playlist", source: { kind: "local" }, artwork: { placeholderSystemImage: symbol },
      duration: tracks.reduce((sum, track) => sum + track.seconds, 0), metadata: {},
      tracks: tracks.map((track) => ({ id: uuid(`music-track:${key}:${track.key}`), name: track.title, duration: track.seconds, source: { kind: "local" }, localReference: local(track), artwork: { placeholderSystemImage: track.symbol } })),
    };
  };
  const singles = MUSIC_TRACKS.map(single);
  const pushMix = playlist("pushMix", "Push Day Mix", "bolt.fill", ["tempo", "lastSet", "sunrise"]);
  const stretch = playlist("stretch", "Stretch & Breathe", "leaf.fill", ["tide", "marble"]);
  const id = (key) => uuid(`music:${key}`);
  return {
    items: [...singles, pushMix, stretch],
    memberships: {
      general: [id("sunrise"), id("marble"), id("tide")],
      types: { Strength: [pushMix.id, id("tempo")], HIIT: [id("lastSet")], Stretch: [stretch.id] },
      mine: { [workoutId("push")]: [pushMix.id, id("lastSet")] },
      route: { run: [id("nightRun"), id("sunrise")], walk: [id("tide")], bike: [id("tempo")] },
    },
  };
}

function buildDefaults(now) {
  const music = buildMusic();
  return {
    "tm.navigation.order.v1": NAVIGATION_ORDER,
    "tm.navigation.rankedAdded": true,
    "tm.navigation.scheduleSettingsAdded": true,
    "tm.navigation.editorGuideSeen": true,
    "home_greeting_strip_migration_v1": true,
    "home_map_opener_migration_v1": true,
    "home_widget_layout_v1": json(homeLayout()),
    "workout_weekly_goal": 5,
    "workout_goals_by_type_v2": json({ Strength: 3, HIIT: 2, Stretch: 1, Other: 1 }),
    "musicGuideCompletedV1": true,
    "music_volume_v1": 0.7,
    "music_track_filenames_v1": MUSIC_TRACKS.map(musicFilename),
    "music_library_items_v2": json(music.items),
    "music_library_memberships_v2": json(music.memberships),
    "outdoor.modeReminder.phase": "confirmed",
    "outdoor.modeReminder.activeAt": now,
    "tm.ranked.mode": "practice",
    "tm.ranked.family": "pushUps",
    "tm.ranked.pushUp": "standardPushUp",
    "tm.ranked.squat": "standardSquat",
    "tm.ranked.core": "forearmPlank",
  };
}

export function buildDemo(now = new Date()) {
  const rng = random(20261026);
  const history = buildHistory(now, rng);
  const workouts = buildWorkouts(now);
  const sectionPhotos = workouts.flatMap((workout) => workout.sections.flatMap((section) => section.mediaFilenames));
  return {
    pages: buildPages(now),
    workouts,
    history,
    config: buildConfig(now),
    activities: OUTINGS.map((outing) => buildActivity(outing, now, rng)),
    plannedRoutes: buildPlannedRoutes(now),
    practice: buildPractice(now),
    profile: buildProfile(now, currentStreak(history, now)),
    photos: [...new Set([
      "profile-avatar.jpg", "profile-banner.jpg", ...sectionPhotos,
      ...WORKOUTS.filter((workout) => workout.cover).map((workout) => `cover-${workout.cover}.jpg`),
    ])],
    defaults: buildDefaults(now),
  };
}
