// Static demo content: the exercise library, the workouts built from it, and the weekly plan.
import { uuid } from "./util.mjs";

export const TYPES = {
  Strength: { id: "Strength", name: "Strength", iconName: "dumbbell.fill", colorHex: "FF9500" },
  Stretch: { id: "Stretch", name: "Stretch", iconName: "figure.cooldown", colorHex: "34C759" },
  Cardio: { id: "Cardio", name: "Cardio", iconName: "heart.fill", colorHex: "FF3B30" },
  HIIT: { id: "HIIT", name: "HIIT", iconName: "flame.fill", colorHex: "FF2D55" },
  Other: { id: "Other", name: "Other", iconName: "star.fill", colorHex: "007AFF" },
};

export const GROUPS = [
  { key: "push", title: "Push-Ups", type: "Strength", body: "Seven push-up variations, from the first clean rep to the diamond." },
  { key: "legs", title: "Squats", type: "Strength", body: "Bodyweight squat patterns for strong, springy legs." },
  { key: "core", title: "Core", type: "HIIT", body: "Planks and side planks. Brace like you mean it." },
  { key: "skills", title: "Handstand & Planche", type: "Other", body: "Inverted and straight-arm skills. Patience required, bragging rights included." },
  { key: "recovery", title: "Recovery", type: "Stretch", body: "Mobility and cooldowns that keep you training tomorrow." },
];

const cues = (intro, ...items) => `${intro}\n\n**Cues**\n${items.map((item) => `- ${item}`).join("\n")}`;

/** `art` names a Ranked movement illustration; recovery moves have no illustration. */
export const EXERCISES = [
  { key: "standardPushUp", group: "push", title: "Push-Up", duration: 40, sets: 3, rest: 20, comment: "Elbows at 45°, ribs down.",
    body: cues("Hands just outside the shoulders, body in one straight line from head to heels.", "Elbows track back at about 45°", "Chest to fist height, then press the floor away", "Squeeze the glutes so the hips never sag") },
  { key: "widePushUp", group: "push", title: "Wide Push-Up", duration: 40, sets: 3, rest: 20, comment: "Wide hands, proud chest.",
    body: cues("Hands a forearm's length wider than the shoulders to load the chest.", "Soft elbows at the top", "Lower until the chest is level with the hands", "End the set when the hips start to drop") },
  { key: "closePushUp", group: "push", title: "Close-Grip Push-Up", duration: 40, sets: 3, rest: 20, comment: "Elbows skim the ribs.",
    body: cues("Hands under the shoulders, elbows brushing the ribs. The triceps do the heavy lifting.", "Forearms stay vertical", "Full lockout on every rep") },
  { key: "kneePushUp", group: "push", title: "Knee Push-Up", duration: 40, sets: 3, rest: 15, comment: "Hips long, never piked.",
    body: cues("The regression that builds the real thing. Knees down, hips in line with the shoulders.", "Same hand position as a full push-up", "Slow down on the way down") },
  { key: "pausedPushUp", group: "push", title: "Paused Push-Up", duration: 45, sets: 3, rest: 25, comment: "Hold here for two seconds.",
    body: cues("A two-second hold one inch above the floor on every rep.", "Keep the tension, never rest on the floor", "Explode up after the pause") },
  { key: "tempoPushUp", group: "push", title: "Tempo Push-Up", duration: 45, sets: 2, rest: 30, comment: "3 down, 1 hold, 1 up.",
    body: cues("Three seconds down, one second hold, one second up. Time under tension, zero momentum.", "Count the descent out loud", "Keep the neck neutral") },
  { key: "diamondPushUp", group: "push", title: "Diamond Push-Up", duration: 30, sets: 3, rest: 25, comment: "Diamond under the sternum.",
    body: cues("Thumbs and index fingers form a diamond under the sternum.", "Elbows stay close to the body", "Lower the chest all the way to the hands") },
  { key: "standardSquat", group: "legs", title: "Bodyweight Squat", duration: 45, sets: 4, rest: 15, comment: "Sit between the heels.",
    body: cues("Feet shoulder width apart. Sit the hips back and down between the heels.", "Knees track over the toes", "Chest up, weight across the whole foot", "Hips just below the knees") },
  { key: "wideSquat", group: "legs", title: "Sumo Squat", duration: 40, sets: 3, rest: 15, comment: "Knees out, chest tall.",
    body: cues("Wide stance, toes turned out, torso tall. Inner thighs and glutes do the work.", "Push the knees out over the toes", "Pause briefly at the bottom") },
  { key: "narrowSquat", group: "legs", title: "Narrow Squat", duration: 40, sets: 3, rest: 15, comment: "Heels glued to the floor.",
    body: cues("Feet together, sit straight down. Quads and balance.", "Arms forward as a counterweight", "Heels stay down the whole time") },
  { key: "pausedSquat", group: "legs", title: "Paused Squat", duration: 45, sets: 3, rest: 20, comment: "Three seconds in the hole.",
    body: cues("A three-second pause at the bottom of every rep. No bounce allowed.", "Stay tight at the bottom", "Drive up through the mid-foot") },
  { key: "forearmPlank", group: "core", title: "Forearm Plank", duration: 45, sets: 3, rest: 15, comment: "Elbows under the shoulders.",
    body: cues("Elbows under the shoulders, body in one line, squeeze everything.", "Pull the elbows toward the toes", "Breathe behind the brace") },
  { key: "highPlank", group: "core", title: "High Plank", duration: 40, sets: 3, rest: 15, comment: "Push the floor away.",
    body: cues("The top of a push-up, held. Shoulders over wrists.", "Spread the fingers wide", "Ribs down, glutes on") },
  { key: "leftSidePlank", group: "core", title: "Side Plank Left", duration: 30, sets: 2, rest: 10, comment: "Hips high, feet stacked.",
    body: cues("Stack the feet and lift the hips until the body forms one line.", "Elbow directly under the shoulder", "Hips forward, never piked back") },
  { key: "rightSidePlank", group: "core", title: "Side Plank Right", duration: 30, sets: 2, rest: 10, comment: "Long line, head to heels.",
    body: cues("Mirror of the left side. Same line, same squeeze.", "Top hand on the hip or reaching up", "Hold the hips level") },
  { key: "wallHandstandPushUp", group: "skills", title: "Wall Handstand Push-Up", duration: 30, sets: 4, rest: 45, comment: "Head to tripod, then press.",
    body: cues("Kick up to the wall, hands a little wider than the shoulders, lower the head to a tripod.", "Stack wrists, elbows and shoulders", "Press through the whole palm", "Exit with a cartwheel, never a collapse") },
  { key: "freestandingHandstandPushUp", group: "skills", title: "Freestanding Handstand Push-Up", duration: 20, sets: 5, rest: 60, comment: "The fingers steer the balance.",
    body: cues("The end boss. Balance on the fingers, lower under control, press back to a stacked line.", "Grip the floor to correct the balance", "Legs tight together") },
  { key: "planchePushUp", group: "skills", title: "Planche Push-Up", duration: 20, sets: 4, rest: 60, comment: "Lean, protract, float.",
    body: cues("Lean the shoulders far past the hands and float the feet. Serious straight-arm strength.", "Protract the shoulder blades hard", "Point the toes and lock the knees") },
  { key: "catCow", group: "recovery", title: "Cat-Cow", duration: 60, sets: 1, rest: 10, art: null,
    body: cues("On all fours, move slowly between a rounded and an arched spine.", "Lead with the tailbone", "Breathe out as you round") },
  { key: "worldsGreatest", group: "recovery", title: "World's Greatest Stretch", duration: 45, sets: 2, rest: 10, art: null,
    body: cues("Deep lunge, elbow to the instep, then rotate and reach for the ceiling.", "Back knee off the floor", "Follow the hand with the eyes") },
  { key: "hipFlexor", group: "recovery", title: "Hip Flexor Stretch", duration: 40, sets: 2, rest: 10, art: null,
    body: cues("Half-kneeling, tuck the pelvis and shift forward until the front of the hip opens.", "Squeeze the back glute", "Tall torso") },
  { key: "thoracicRotation", group: "recovery", title: "Thoracic Rotation", duration: 45, sets: 1, rest: 10, art: null,
    body: cues("Side-lying, knees stacked, open the top arm like a book.", "Keep the knees together", "Exhale into the rotation") },
  { key: "childsPose", group: "recovery", title: "Child's Pose", duration: 60, sets: 1, rest: 0, art: null,
    body: cues("Knees wide, hips to the heels, arms long in front.", "Let the forehead rest", "Slow breaths into the back ribs") },
];

export const WORKOUTS = [
  { key: "push", name: "Push Day Ladder", type: "Strength", prepare: 5, restBetweenSections: 40, sections: [
    ["standardPushUp", { sets: 3, duration: 40, reps: 12, rest: 20 }],
    ["widePushUp", { sets: 3, duration: 40, reps: 10, rest: 20 }],
    ["diamondPushUp", { sets: 3, duration: 30, reps: 8, rest: 25 }],
    ["tempoPushUp", { sets: 2, duration: 45, reps: 6, rest: 30 }],
    ["wallHandstandPushUp", { sets: 3, duration: 30, reps: 5, rest: 40 }],
  ] },
  { key: "legs", name: "Leg Day Power", type: "Strength", prepare: 5, restBetweenSections: 30, sections: [
    ["standardSquat", { sets: 4, duration: 45, reps: 20, rest: 15 }],
    ["wideSquat", { sets: 3, duration: 40, reps: 15, rest: 15 }],
    ["narrowSquat", { sets: 3, duration: 40, reps: 15, rest: 15 }],
    ["pausedSquat", { sets: 3, duration: 45, reps: 10, rest: 20 }],
  ] },
  { key: "core", name: "Core Crusher", type: "HIIT", prepare: 5, restBetweenSections: 20, sections: [
    ["forearmPlank", { sets: 3, duration: 45, rest: 15 }],
    ["highPlank", { sets: 3, duration: 40, rest: 15 }],
    ["leftSidePlank", { sets: 2, duration: 30, rest: 10 }],
    ["rightSidePlank", { sets: 2, duration: 30, rest: 10 }],
  ] },
  { key: "full", name: "Full Body Burner", type: "HIIT", prepare: 5, restBetweenSections: 20, sections: [
    ["standardPushUp", { sets: 3, duration: 40, reps: 15, rest: 15 }],
    ["standardSquat", { sets: 3, duration: 40, reps: 20, rest: 15 }],
    ["highPlank", { sets: 3, duration: 40, rest: 15 }],
    ["widePushUp", { sets: 3, duration: 35, reps: 12, rest: 15 }],
    ["wideSquat", { sets: 3, duration: 40, reps: 15, rest: 15 }],
    ["forearmPlank", { sets: 2, duration: 45, rest: 15 }],
  ] },
  { key: "skills", name: "Handstand Skill Session", type: "Other", prepare: 5, restBetweenSections: 45, sections: [
    ["wallHandstandPushUp", { sets: 4, duration: 30, reps: 5, rest: 45 }],
    ["freestandingHandstandPushUp", { sets: 5, duration: 20, reps: 2, rest: 60 }],
    ["planchePushUp", { sets: 4, duration: 20, reps: 3, rest: 60 }],
    ["closePushUp", { sets: 3, duration: 40, reps: 12, rest: 20 }],
  ] },
  { key: "mobility", name: "Morning Mobility", type: "Stretch", prepare: 4, restBetweenSections: 10, cover: "recovery", sections: [
    ["catCow", { sets: 1, duration: 60, rest: 10 }],
    ["worldsGreatest", { sets: 2, duration: 45, rest: 10 }],
    ["hipFlexor", { sets: 2, duration: 40, rest: 10 }],
    ["thoracicRotation", { sets: 1, duration: 45, rest: 10 }],
    ["childsPose", { sets: 1, duration: 60, rest: 10 }],
  ] },
];

/** The equipped weekly plan (weekday 1 = Monday) and a second saved plan for the plan library. */
export const PLANS = [
  { key: "hybrid", name: "Hybrid Week", icon: "square.stack.3d.up.fill", entries: [
    { weekday: 1, workout: "push", start: 7 * 60 },
    { weekday: 1, workout: "core", start: 19 * 60 + 30 },
    { weekday: 2, workout: "legs", start: 7 * 60 },
    { weekday: 3, workout: "full", start: 18 * 60 },
    { weekday: 4, workout: "skills", start: 7 * 60 + 30 },
    { weekday: 5, workout: "push", start: 7 * 60 },
    { weekday: 6, workout: "legs", start: 9 * 60 },
    { weekday: 7, workout: "mobility", start: 9 * 60 + 30 },
  ] },
  { key: "deload", name: "Deload Week", icon: "leaf.fill", entries: [
    { weekday: 1, workout: "mobility", start: 7 * 60 },
    { weekday: 3, workout: "core", start: 18 * 60 },
    { weekday: 5, workout: "full", start: 7 * 60 },
    { weekday: 7, workout: "mobility", start: 9 * 60 + 30 },
  ] },
];

export const pageId = (key) => uuid(`page:${key}`);
export const groupId = (key) => uuid(`group:${key}`);
export const workoutId = (key) => uuid(`workout:${key}`);

export function workoutSeconds(workout) {
  const sections = workout.sections.map(([, set]) => 4 + set.sets * set.duration + (set.sets - 1) * set.rest);
  return workout.prepare + sections.reduce((sum, value) => sum + value, 0) + workout.restBetweenSections * (sections.length - 1);
}
