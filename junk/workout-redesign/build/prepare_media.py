"""Builds the live example's data from the user's REAL library: the real workout, its real exercise pages and their real videos.

Videos are copied into junk/workout-redesign/media (git-ignored) without audio, scaled to at most 720 px wide, so they loop in any browser.
Run:  python3 prepare_media.py
"""
import glob
import json
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, ".."))
MEDIA = os.path.join(OUT, "media")
LIB = os.path.expanduser("~/Library/Application Support/TimeMaster")
WORKOUT_ID = "0C591731-F5FE-4BF9-A7DF-DF7A87828ABF"  # W2 Tue PM · Wrestling 1 (solo technique)
SECTIONS = [0, 4, 6]  # Wrestler circuit (bundle), Sprawls (timed), Bridge + neck (bundle, 3 rounds)

os.makedirs(MEDIA, exist_ok=True)


def load_pages():
    pages = {}
    for mf in glob.glob(LIB + "/Exercises Database/**/manifest.json", recursive=True):
        d = os.path.dirname(mf)
        try:
            m = json.load(open(mf))
        except Exception:
            continue
        media = os.path.join(d, "media")
        files = sorted(os.listdir(media)) if os.path.isdir(media) else []
        pages[m["id"]] = {"title": m.get("title"), "files": [os.path.join(media, x) for x in files]}
    return pages


def leafs(slot):
    if slot.get("children"):
        for child in slot["children"]:
            yield from leafs(child)
    else:
        yield slot


def convert(src, slug):
    video = os.path.join(MEDIA, slug + ".mp4")
    poster = os.path.join(MEDIA, slug + ".jpg")
    if not os.path.exists(video):
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src, "-an", "-vf", "scale='min(720,iw)':-2", "-c:v", "libx264", "-crf", "24",
                        "-preset", "veryfast", "-pix_fmt", "yuv420p", "-movflags", "+faststart", video], check=True)
    if not os.path.exists(poster):
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", "0.6", "-i", video, "-frames:v", "1", "-vf", "scale=540:-2", "-q:v", "4", poster], check=True)
    probe = json.loads(subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height:format=duration",
                                       "-of", "json", video], capture_output=True, text=True).stdout)
    st = probe["streams"][0]
    return {"type": "video", "src": f"media/{slug}.mp4", "poster": f"media/{slug}.jpg", "w": st["width"], "h": st["height"],
            "seconds": round(float(probe["format"]["duration"]), 1)}


def main():
    pages = load_pages()
    workout = json.load(open(f"{LIB}/Workouts/{WORKOUT_ID}/manifest.json"))
    cache = {}

    def media_for(page_id):
        if page_id in cache:
            return cache[page_id]
        page = pages.get(page_id)
        items = []
        if page:
            for n, fp in enumerate(page["files"]):
                if fp.lower().endswith((".mp4", ".mov", ".m4v")):
                    slug = f"{page_id[:8].lower()}-{n}"
                    items.append(convert(fp, slug))
        cache[page_id] = items
        return items

    out = {"name": workout["name"], "restBetweenSections": workout.get("restBetweenSections", 20), "prepareTime": workout.get("prepareTime", 4), "sections": []}
    for index in SECTIONS:
        sec = workout["sections"][index]
        sets = []
        for top in sec["slots"]:
            children = list(leafs(top)) if top.get("children") else [top]
            row = []
            for leaf in children:
                page = pages.get(leaf.get("exerciseID"))
                row.append({
                    "id": leaf["id"], "name": leaf["name"], "page": page["title"] if page else leaf["name"],
                    "dur": leaf.get("duration", 30), "restAfter": leaf.get("restAfter", 0) or 0, "reps": leaf.get("repCount"),
                    "media": media_for(leaf.get("exerciseID")),
                })
            sets.append({"prep": top.get("prepareTime", sec.get("prepareTime", 0)) or 0, "restAfter": top.get("restAfter", 0) or 0, "items": row})
        out["sections"].append({
            "name": sec["name"], "mode": sec["mode"], "setCount": sec.get("sets", 1), "restBetweenSets": sec.get("restBetweenSets", 0),
            "order": sec.get("bundleOrder", "ordered"), "voice": sec.get("bundleVoiceEnabled", True), "sets": sets,
        })
    with open(os.path.join(HERE, "example-data.json"), "w") as fh:
        json.dump(out, fh, indent=1, ensure_ascii=False)
    for s in out["sections"]:
        print(s["mode"], "|", s["name"][:60], "| sets", len(s["sets"]), "| setRest", s["restBetweenSets"])
        for st in s["sets"][:2]:
            print("   set prep", st["prep"], "restAfter", st["restAfter"], [(i["name"][:26], i["dur"], i["restAfter"], len(i["media"])) for i in st["items"]])


if __name__ == "__main__":
    main()
