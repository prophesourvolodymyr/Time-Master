import asyncio
import base64
import hashlib
import hmac
import json
import math
import os
import re
import secrets
import sqlite3
import time
from contextlib import contextmanager, asynccontextmanager, closing
from pathlib import Path
from typing import Annotated

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field, field_validator
from .rules import VERSION, VARIATIONS, ADVANCED, CORE, JOINTS, Tracker, assess, elo, family

DB_PATH = os.environ.get("RANKED_DATABASE", "ranked.sqlite3")
TERMINAL = {"completed", "forfeited", "invalid", "cancelled"}
WINDOW = 14400
LIMIT = 10
ROUND_SECONDS = 60
RECONNECT_SECONDS = 8


def now():
    return time.time()


def fail(code, message):
    raise HTTPException(code, message)


@contextmanager
def transaction():
    db = sqlite3.connect(DB_PATH, timeout=15, isolation_level=None)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys=ON")
    try:
        db.execute("BEGIN IMMEDIATE")
        yield db
        db.commit()
    except BaseException:
        db.rollback()
        raise
    finally:
        db.close()


def initialize():
    Path(DB_PATH).parent.mkdir(parents=True, exist_ok=True)
    with closing(sqlite3.connect(DB_PATH)) as db:
        db.executescript(Path(__file__).with_name("schema.sql").read_text())
    os.chmod(DB_PATH, 0o600)


@asynccontextmanager
async def lifespan(app):
    initialize()

    async def clock():
        while True:
            await asyncio.sleep(0.2)
            await asyncio.to_thread(tick)

    task = asyncio.create_task(clock())
    try:
        yield
    finally:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass


app = FastAPI(title="TimeMaster Ranked", version="1", lifespan=lifespan, docs_url=None, redoc_url=None)


@app.middleware("http")
async def boundary(request: Request, call_next):
    if os.environ.get("RANKED_REQUIRE_TLS", "true") == "true" and request.url.scheme != "https":
        from starlette.responses import JSONResponse
        return JSONResponse({"detail": "HTTPS required"}, status_code=426)
    size = request.headers.get("content-length", "0")
    if not size.isdecimal():
        from starlette.responses import JSONResponse
        return JSONResponse({"detail": "Invalid content length"}, status_code=400)
    if len(size) > 9 or int(size) > 262144:
        from starlette.responses import JSONResponse
        return JSONResponse({"detail": "Request too large"}, status_code=413)
    if request.method == "POST":
        body = await request.body()
        if len(body) > 262144:
            from starlette.responses import JSONResponse
            return JSONResponse({"detail": "Request too large"}, status_code=413)
    response = await call_next(request)
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response


class Input(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False)


class Credentials(Input):
    login: str = Field(min_length=3, max_length=64)
    password: str = Field(min_length=12, max_length=128)

    @field_validator("login")
    @classmethod
    def normalize(cls, value):
        value = value.strip().lower()
        if not re.fullmatch(r"[a-z0-9_.@+-]{3,64}", value):
            raise ValueError("Use a private login of 3–64 letters, numbers or . _ @ + -")
        return value


class Registration(Credentials):
    displayName: str = Field(min_length=1, max_length=60)
    listed: bool = False


class Refresh(Input):
    refreshToken: str = Field(min_length=32, max_length=128)


class QueueEntry(Input):
    variation: str
    ruleVersion: str
    requestID: str = Field(min_length=16, max_length=80)


class Joint(Input):
    x: float
    y: float
    confidence: float = Field(ge=0, le=1)


class Pose(Input):
    time: float
    aspect: float = Field(ge=0.2, le=5)
    people: int = Field(ge=0, le=100)
    joints: dict[str, Joint] = Field(max_length=13)
    light: float = Field(ge=0, le=1)
    cameraMoving: bool
    diamondContact: bool | None = None

    @field_validator("joints")
    @classmethod
    def known_joints(cls, value):
        if any(n not in JOINTS for n in value):
            raise ValueError("Unknown body joint")
        return value


class Ready(Input):
    ready: bool
    calibration: list[Pose] = Field(default_factory=list, max_length=30)


class Presence(Input):
    active: bool
    calibrated: bool


class Evidence(Input):
    nonce: str = Field(min_length=32, max_length=128)
    ruleVersion: str
    sequence: int = Field(ge=0, le=10000)
    frames: list[Pose] = Field(min_length=1, max_length=30)


class Privacy(Input):
    displayName: str = Field(min_length=1, max_length=60)
    listed: bool


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def password_hash(password, salt=None):
    salt = salt or secrets.token_hex(16)
    result = hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt), n=32768, r=8, p=1, maxmem=67108864).hex()
    return salt + ":" + result


DUMMY_PASSWORD = password_hash(secrets.token_urlsafe(24))


def session_grant(db, uid, session_family=None):
    access, refresh = secrets.token_urlsafe(32), secrets.token_urlsafe(48)
    t = now()
    db.execute("INSERT INTO sessions VALUES (?,?,?,?,?,?,0)", (digest(access), digest(refresh), uid, session_family or secrets.token_hex(16), t + 900, t + 2592000))
    return dict(accessToken=access, refreshToken=refresh, expiresAt=t + 900)


def authenticated(authorization: Annotated[str | None, Header()] = None):
    if not authorization or not authorization.startswith("Bearer "):
        fail(401, "Sign in to Ranked")
    with transaction() as db:
        row = db.execute("SELECT user_id FROM sessions WHERE access_hash=? AND revoked=0 AND access_expires>?", (digest(authorization[7:]), now())).fetchone()
    if not row:
        fail(401, "Session expired · Sign in again")
    return row["user_id"]


def throttle(request, login, registration=False):
    key = digest((request.client.host if request.client else "local") + ("register" if registration else login))
    with transaction() as db:
        t = now()
        span, limit = (3600, 5) if registration else (600, 10)
        db.execute("DELETE FROM auth_limits WHERE at<?", (t - 3600,))
        count = db.execute("SELECT count(*) FROM auth_limits WHERE bucket=? AND at>?", (key, t - span)).fetchone()[0]
        if count >= limit:
            fail(429, "Too many attempts · Try again later")
        db.execute("INSERT INTO auth_limits VALUES (?,?)", (key, t))


@app.get("/health")
def health():
    return {"status": "ok", "rules": VERSION}


@app.get("/v1/catalog")
def catalog():
    return {"ruleVersion": VERSION, "roundSeconds": 60, "evidenceRetentionHours": 24,
            "integrity": "Derived pose validation, not proof against replay or hidden assistance",
            "movements": [{"variation": v, "competitive": v not in ADVANCED,
                           "reason": "Recording-based inverted/hand/support validation is not yet established" if v in ADVANCED else None} for v in VARIATIONS]}


@app.post("/v1/auth/register")
def register(body: Registration, request: Request):
    throttle(request, body.login, True)
    hashed = password_hash(body.password)
    try:
        with transaction() as db:
            uid = secrets.token_hex(16)
            db.execute("INSERT INTO accounts VALUES (?,?,?,?,?,?,?)", (uid, secrets.token_urlsafe(16), body.login, hashed, body.displayName.strip() or "Athlete", int(body.listed), now()))
            return session_grant(db, uid)
    except sqlite3.IntegrityError:
        fail(409, "This login is unavailable")


@app.post("/v1/auth/login")
def login(body: Credentials, request: Request):
    throttle(request, body.login)
    with transaction() as db:
        row = db.execute("SELECT id,password FROM accounts WHERE login=?", (body.login,)).fetchone()
    stored = row["password"] if row else DUMMY_PASSWORD
    if not hmac.compare_digest(stored, password_hash(body.password, stored.split(":")[0])) or not row:
        fail(401, "Incorrect login or password")
    with transaction() as db:
        return session_grant(db, row["id"])


@app.post("/v1/auth/refresh")
def refresh(body: Refresh):
    with transaction() as db:
        row = db.execute("SELECT * FROM sessions WHERE refresh_hash=?", (digest(body.refreshToken),)).fetchone()
        if not row or row["refresh_expires"] <= now() or row["revoked"]:
            fail(401, "Session expired · Sign in again")
        db.execute("UPDATE sessions SET revoked=1 WHERE access_hash=?", (row["access_hash"],))
        return session_grant(db, row["user_id"], row["family"])


@app.post("/v1/auth/logout")
def logout(uid=Depends(authenticated), authorization: str = Header()):
    with transaction() as db:
        session = db.execute("SELECT family FROM sessions WHERE access_hash=?", (digest(authorization[7:]),)).fetchone()
        cancel(db, uid, "Signed out")
        db.execute("UPDATE sessions SET revoked=1 WHERE user_id=? AND family=?", (uid, session["family"]))
    return {"ok": True}


def rating(db, uid, variation):
    row = db.execute("SELECT rating,games FROM ratings WHERE user_id=? AND variation=?", (uid, variation)).fetchone()
    return (row["rating"], row["games"]) if row else (1000, 0)


def allowance(db, uid, f, t):
    if f == "core":
        return dict(family=f, remaining=None, nextSlot=None)
    starts = db.execute("SELECT at FROM starts WHERE user_id=? AND family=? AND at>? ORDER BY at", (uid, f, t - WINDOW)).fetchall()
    return dict(family=f, remaining=max(0, LIMIT - len(starts)), nextSlot=starts[0]["at"] + WINDOW if len(starts) >= LIMIT else None)


def account(db, uid):
    a = db.execute("SELECT public_id,display_name,listed FROM accounts WHERE id=?", (uid,)).fetchone()
    return dict(publicID=a["public_id"], displayName=a["display_name"], listed=bool(a["listed"]))


@app.get("/v1/me")
def me(uid=Depends(authenticated)):
    with transaction() as db:
        sweep(db)
        return dict(identity=account(db, uid), ratings=[dict(variation=r["variation"], rating=r["rating"], games=r["games"]) for r in db.execute("SELECT * FROM ratings WHERE user_id=? ORDER BY variation", (uid,))], allowances=[allowance(db, uid, f, now()) for f in ("pushUps", "squats", "core")])


@app.post("/v1/me/privacy")
def privacy(body: Privacy, uid=Depends(authenticated)):
    with transaction() as db:
        db.execute("UPDATE accounts SET display_name=?,listed=? WHERE id=?", (body.displayName.strip() or "Athlete", int(body.listed), uid))
        return account(db, uid)


def owned(db, uid, mid):
    row = db.execute("SELECT m.* FROM matches m JOIN participants p ON p.match_id=m.id WHERE m.id=? AND p.user_id=?", (mid, uid)).fetchone()
    if not row:
        fail(404, "Match unavailable")
    return row


def match_view(db, uid, mid):
    m = owned(db, uid, mid)
    people = []
    for p in db.execute("SELECT p.*,a.public_id,a.display_name FROM participants p JOIN accounts a ON a.id=p.user_id WHERE match_id=? ORDER BY a.public_id", (mid,)):
        people.append(dict(publicID=p["public_id"], displayName=p["display_name"], isYou=p["user_id"] == uid,
                           ready=bool(p["ready"]), score=p["score"], lastSeen=p["last_seen"],
                           verification=p["verification"], beforeRating=p["before_rating"], afterRating=p["after_rating"],
                           nonce=p["nonce"] if p["user_id"] == uid else None,
                           nextSequence=p["sequence"] if p["user_id"] == uid else None))
    winner = db.execute("SELECT public_id FROM accounts WHERE id=?", (m["winner"],)).fetchone() if m["winner"] else None
    return dict(id=mid, variation=m["variation"], ruleVersion=m["rules"], state=m["state"], createdAt=m["created"], readyDeadline=m["ready_deadline"], startAt=m["start"], endAt=m["end"], reason=m["reason"], winner=winner[0] if winner else None, revision=m["revision"], participants=people)


def state_view(db, uid):
    a = db.execute("SELECT match_id FROM active WHERE user_id=?", (uid,)).fetchone()
    q = db.execute("SELECT * FROM queue WHERE user_id=?", (uid,)).fetchone()
    return dict(serverTime=now(), queue=dict(variation=q["variation"], expiresAt=q["created"] + 90) if q else None, match=match_view(db, uid, a["match_id"]) if a else None)


@app.get("/v1/state")
def state(uid=Depends(authenticated)):
    with transaction() as db:
        sweep(db)
        db.execute("UPDATE queue SET heartbeat=? WHERE user_id=?", (now(), uid))
        db.execute("UPDATE participants SET last_seen=? WHERE user_id=? AND match_id IN (SELECT match_id FROM active WHERE user_id=?)", (now(), uid, uid))
        return state_view(db, uid)


@app.post("/v1/queue")
def enqueue(body: QueueEntry, uid=Depends(authenticated)):
    if body.variation not in VARIATIONS or body.ruleVersion != VERSION:
        fail(409, "Update the app to use the current movement rules")
    if body.variation in ADVANCED:
        fail(422, "Ranked verification for this advanced movement needs validated recordings and support evidence. Real camera-tracked Practice is available.")
    with transaction() as db:
        sweep(db)
        seen = db.execute("SELECT operation FROM requests WHERE user_id=? AND request_id=?", (uid, body.requestID)).fetchone()
        if seen:
            if seen["operation"] != body.variation:
                fail(409, "Request identity was already used for another movement")
            return state_view(db, uid)
        if db.execute("SELECT 1 FROM active WHERE user_id=?", (uid,)).fetchone() or db.execute("SELECT 1 FROM queue WHERE user_id=?", (uid,)).fetchone():
            return state_view(db, uid)
        if allowance(db, uid, family(body.variation), now())["remaining"] == 0:
            fail(429, "No match slots available · Wait for the next rolling slot")
        r, _ = rating(db, uid, body.variation)
        t = now()
        db.execute("INSERT INTO requests VALUES (?,?,?,?)", (uid, body.requestID, body.variation, t))
        db.execute("INSERT INTO queue VALUES (?,?,?,?,?,?)", (uid, body.variation, VERSION, r, t, t))
        pair(db)
        return state_view(db, uid)


def pair(db):
    t = now()
    rows = db.execute("SELECT * FROM queue ORDER BY created,user_id").fetchall()
    claimed = set()
    for a in rows:
        if a["user_id"] in claimed:
            continue
        candidates = [b for b in rows if b["user_id"] != a["user_id"] and b["user_id"] not in claimed and b["variation"] == a["variation"] and b["rules"] == a["rules"] and abs(a["rating"] - b["rating"]) <= min(300, 100 + 25 * int(min(t - a["created"], t - b["created"]) / 10))]
        if not candidates:
            continue
        b = min(candidates, key=lambda b: (abs(a["rating"] - b["rating"]), b["created"], b["user_id"]))
        mid = secrets.token_hex(16)
        db.execute("INSERT INTO matches(id,variation,rules,state,created,ready_deadline) VALUES (?,?,?,'matched',?,?)", (mid, a["variation"], VERSION, t, t + 45))
        for q in (a, b):
            u = q["user_id"]
            db.execute("INSERT INTO participants(match_id,user_id,nonce,last_seen,tracker) VALUES (?,?,?,?,?)", (mid, u, secrets.token_urlsafe(32), t, json.dumps(Tracker(q["variation"]).snapshot())))
            db.execute("INSERT INTO active VALUES (?,?)", (u, mid))
            db.execute("DELETE FROM queue WHERE user_id=?", (u,))
            claimed.add(u)


def cancel(db, uid, reason):
    sweep(db)
    db.execute("DELETE FROM queue WHERE user_id=?", (uid,))
    a = db.execute("SELECT match_id FROM active WHERE user_id=?", (uid,)).fetchone()
    if a:
        m = owned(db, uid, a["match_id"])
        if m["state"] in ("matched", "countdown"):
            finalize(db, m, "cancelled", reason)
        elif m["state"] == "live":
            opponent = db.execute("SELECT user_id FROM participants WHERE match_id=? AND user_id<>?", (m["id"], uid)).fetchone()[0]
            finalize(db, m, "forfeited", reason, opponent)


@app.post("/v1/queue/cancel")
def cancel_queue(uid=Depends(authenticated)):
    with transaction() as db:
        cancel(db, uid, "Cancelled before Go")
        return state_view(db, uid)


@app.get("/v1/matches/{mid}")
def get_match(mid: str, uid=Depends(authenticated)):
    with transaction() as db:
        sweep(db)
        owned(db, uid, mid)
        db.execute("UPDATE participants SET last_seen=? WHERE match_id=? AND user_id=?", (now(), mid, uid))
        return dict(serverTime=now(), match=match_view(db, uid, mid))


@app.post("/v1/matches/{mid}/ready")
def ready(mid: str, body: Ready, uid=Depends(authenticated)):
    with transaction() as db:
        sweep(db)
        m = owned(db, uid, mid)
        if m["state"] in TERMINAL:
            return dict(serverTime=now(), match=match_view(db, uid, mid))
        if m["state"] not in ("matched", "countdown"):
            fail(409, "The round has already started")
        if not body.ready and m["state"] == "countdown":
            finalize(db, m, "cancelled", "Camera readiness was lost before Go")
        else:
            if body.ready:
                poses = [p.model_dump() for p in body.calibration]
                if len(poses) < 10 or poses[-1]["time"] - poses[0]["time"] < 1.4 or poses[-1]["time"] - poses[0]["time"] > 4:
                    fail(422, "Hold a stable starting pose for calibration")
                if any(not (a := assess(p, m["variation"]))["valid"] or not a["top"] for p in poses) or any(not 0 < b["time"] - a["time"] <= 0.25 for a, b in zip(poses, poses[1:])):
                    fail(422, "Calibration needs one visible athlete in the starting position")
            db.execute("UPDATE participants SET ready=?,last_seen=? WHERE match_id=? AND user_id=?", (int(body.ready), now(), mid, uid))
            db.execute("UPDATE matches SET revision=revision+1 WHERE id=?", (mid,))
            if db.execute("SELECT count(*) FROM participants WHERE match_id=? AND ready=1", (mid,)).fetchone()[0] == 2 and m["state"] == "matched":
                t = now() + 4
                db.execute("UPDATE matches SET state='countdown',start=?,end=?,revision=revision+1 WHERE id=?", (t, t + ROUND_SECONDS, mid))
        return dict(serverTime=now(), match=match_view(db, uid, mid))


@app.post("/v1/matches/{mid}/presence")
def presence(mid: str, body: Presence, uid=Depends(authenticated)):
    with transaction() as db:
        sweep(db)
        m = owned(db, uid, mid)
        db.execute("UPDATE participants SET last_seen=? WHERE match_id=? AND user_id=?", (now(), mid, uid))
        if not body.active and m["state"] == "live":
            other = db.execute("SELECT user_id FROM participants WHERE match_id=? AND user_id<>?", (mid, uid)).fetchone()[0]
            finalize(db, m, "forfeited", "Participant left or backgrounded after Go", other)
        elif not body.active and m["state"] in ("matched", "countdown"):
            finalize(db, m, "cancelled", "Participant left before Go")
        elif not body.calibrated and m["state"] in ("matched", "countdown"):
            if m["state"] == "countdown":
                finalize(db, m, "cancelled", "Camera readiness was lost before Go")
            else:
                db.execute("UPDATE participants SET ready=0 WHERE match_id=? AND user_id=?", (mid, uid))
        return dict(serverTime=now(), match=match_view(db, uid, mid))


@app.post("/v1/matches/{mid}/evidence")
def evidence(mid: str, body: Evidence, uid=Depends(authenticated)):
    with transaction() as db:
        sweep(db)
        m = owned(db, uid, mid)
        p = db.execute("SELECT * FROM participants WHERE match_id=? AND user_id=?", (mid, uid)).fetchone()
        if not hmac.compare_digest(body.nonce, p["nonce"]) or body.ruleVersion != m["rules"]:
            fail(403, "Wrong match evidence context")
        frames = [p.model_dump() for p in body.frames]
        serialized = json.dumps(frames, sort_keys=True, separators=(",", ":"))
        hash_value = digest(serialized)
        existing = db.execute("SELECT digest FROM evidence WHERE match_id=? AND user_id=? AND sequence=?", (mid, uid, body.sequence)).fetchone()
        if existing:
            if not hmac.compare_digest(hash_value, existing[0]):
                fail(409, "A different batch already uses this sequence")
            return dict(nextSequence=p["sequence"], score=p["score"])
        if body.sequence != p["sequence"]:
            fail(409, "Evidence must arrive in order; reconnect to reconcile")
        if m["state"] not in ("countdown", "live", "verifying") or m["start"] is None or p["submitted"]:
            fail(409, "This match no longer accepts new evidence")
        elapsed = now() - m["start"]
        tracker = Tracker(**json.loads(p["tracker"]))
        for frame in frames:
            if frame["time"] < -4 or frame["time"] > 60 or frame["time"] > elapsed + 0.35 or frame["time"] < elapsed - RECONNECT_SECONDS:
                fail(422, "Evidence outside the shared scoring timeline")
            if tracker.last is not None and frame["time"] <= tracker.last:
                fail(409, "Duplicate or reversed frame time")
            if tracker.last is not None and frame["time"] - tracker.last < 0.045:
                fail(422, "Evidence rate exceeds capture limits")
            tracker.consume(frame)
        next_sequence = body.sequence + len(frames)
        db.execute("INSERT INTO evidence VALUES (?,?,?,?,?,?,?)", (mid, uid, body.sequence, len(frames), hash_value, serialized, now()))
        db.execute("UPDATE participants SET sequence=?,tracker=?,score=?,last_seen=? WHERE match_id=? AND user_id=?", (next_sequence, json.dumps(tracker.snapshot()), round(tracker.score, 3), now(), mid, uid))
        db.execute("UPDATE matches SET revision=revision+1 WHERE id=?", (mid,))
        return dict(nextSequence=next_sequence, score=tracker.score)


@app.post("/v1/matches/{mid}/submit")
def submit(mid: str, uid=Depends(authenticated)):
    with transaction() as db:
        sweep(db)
        m = owned(db, uid, mid)
        if m["end"] is None or now() < m["end"]:
            fail(409, "The shared round has not ended")
        if m["state"] not in TERMINAL:
            db.execute("UPDATE participants SET submitted=1,last_seen=? WHERE match_id=? AND user_id=?", (now(), mid, uid))
            sweep(db)
        return dict(serverTime=now(), match=match_view(db, uid, mid))


@app.post("/v1/matches/{mid}/leave")
def leave(mid: str, uid=Depends(authenticated)):
    with transaction() as db:
        owned(db, uid, mid)
        a = db.execute("SELECT match_id FROM active WHERE user_id=?", (uid,)).fetchone()
        if a and a["match_id"] == mid:
            cancel(db, uid, "Participant left after Go" if owned(db, uid, mid)["start"] and now() >= owned(db, uid, mid)["start"] else "Participant cancelled before Go")
        return dict(serverTime=now(), match=match_view(db, uid, mid))


def sweep(db):
    t = now()
    db.execute("DELETE FROM queue WHERE heartbeat<? OR created<?", (t - 12, t - 90))
    db.execute("UPDATE evidence SET frames=NULL WHERE received<? AND frames IS NOT NULL", (t - 86400,))
    for m in db.execute("SELECT * FROM matches WHERE state NOT IN ('completed','forfeited','invalid','cancelled')").fetchall():
        ps = db.execute("SELECT * FROM participants WHERE match_id=? ORDER BY user_id", (m["id"],)).fetchall()
        if m["state"] in ("matched", "countdown"):
            if m["ready_deadline"] < t or any(p["last_seen"] < t - RECONNECT_SECONDS for p in ps):
                finalize(db, m, "cancelled", "Readiness expired before Go")
                continue
            if m["state"] == "countdown" and t >= m["start"]:
                f = family(m["variation"])
                if any(allowance(db, p["user_id"], f, m["start"])["remaining"] == 0 for p in ps):
                    finalize(db, m, "cancelled", "A participant has no remaining family allowance")
                    continue
                if f != "core":
                    for p in ps:
                        db.execute("INSERT OR IGNORE INTO starts VALUES (?,?,?,?)", (p["user_id"], m["id"], f, m["start"]))
                db.execute("UPDATE matches SET state='live',revision=revision+1 WHERE id=?", (m["id"],))
                m = db.execute("SELECT * FROM matches WHERE id=?", (m["id"],)).fetchone()
        if m["state"] == "live":
            missing = [p for p in ps if p["last_seen"] < min(t, m["end"]) - RECONNECT_SECONDS]
            if missing:
                if len(missing) == 2:
                    finalize(db, m, "invalid", "Both participants disconnected")
                else:
                    winner = next(p["user_id"] for p in ps if p["user_id"] != missing[0]["user_id"])
                    finalize(db, m, "forfeited", "Reconnection grace expired after Go", winner)
                continue
            if t >= m["end"]:
                db.execute("UPDATE matches SET state='verifying',revision=revision+1 WHERE id=?", (m["id"],))
                m = db.execute("SELECT * FROM matches WHERE id=?", (m["id"],)).fetchone()
        if m["state"] == "verifying" and (all(p["submitted"] for p in ps) or t >= m["end"] + 12):
            sufficient = True
            for p in ps:
                tr = Tracker(**json.loads(p["tracker"]))
                valid = p["submitted"] and tr.covered_seconds >= 55 and tr.valid_seconds >= 48 and (tr.last or 0) >= 59.5 and m["variation"] not in ADVANCED
                db.execute("UPDATE participants SET verification=? WHERE match_id=? AND user_id=?", ("motionValidated" if valid else "insufficientEvidence", m["id"], p["user_id"]))
                sufficient = sufficient and valid
            if not sufficient:
                finalize(db, m, "invalid", "Insufficient movement evidence · No rating change")
            else:
                scores = [math.floor(p["score"] * 10 + 0.0001) / 10 if m["variation"] in CORE else int(p["score"]) for p in ps]
                winner = None if scores[0] == scores[1] else ps[0 if scores[0] > scores[1] else 1]["user_id"]
                finalize(db, m, "completed", "Derived pose evidence validated · Hidden assistance and replay are not ruled out", winner)


def finalize(db, m, state, reason, winner=None):
    current = db.execute("SELECT state FROM matches WHERE id=?", (m["id"],)).fetchone()[0]
    if current in TERMINAL:
        return
    ps = db.execute("SELECT * FROM participants WHERE match_id=? ORDER BY user_id", (m["id"],)).fetchall()
    for p in ps:
        score = math.floor(p["score"] * 10 + 0.0001) / 10 if m["variation"] in CORE else int(p["score"])
        db.execute("UPDATE participants SET score=? WHERE match_id=? AND user_id=?", (score, m["id"], p["user_id"]))
    if state in ("completed", "forfeited"):
        a, b = ps
        ra, ga = rating(db, a["user_id"], m["variation"])
        rb, gb = rating(db, b["user_id"], m["variation"])
        result = 0.5 if winner is None else 1 if winner == a["user_id"] else 0
        na, nb = elo(ra, rb, result, ga, gb)
        for p, before, after, games in ((a, ra, na, ga), (b, rb, nb, gb)):
            db.execute("INSERT INTO ratings VALUES (?,?,?,?,'elo-1') ON CONFLICT(user_id,variation) DO UPDATE SET rating=excluded.rating,games=excluded.games,policy=excluded.policy", (p["user_id"], m["variation"], after, games + 1))
            db.execute("UPDATE participants SET before_rating=?,after_rating=? WHERE match_id=? AND user_id=?", (before, after, m["id"], p["user_id"]))
    db.execute("UPDATE matches SET state=?,reason=?,winner=?,finalized=?,revision=revision+1 WHERE id=?", (state, reason, winner, now(), m["id"]))
    db.execute("DELETE FROM active WHERE match_id=?", (m["id"],))


def tick():
    with transaction() as db:
        sweep(db)
        pair(db)


def encode_cursor(value):
    return base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip("=")


def decode_cursor(value):
    try:
        if len(value) > 256:
            raise ValueError()
        return json.loads(base64.urlsafe_b64decode(value + "=" * (-len(value) % 4)))
    except (ValueError, TypeError):
        fail(422, "Invalid page cursor")


@app.get("/v1/history")
def history(cursor: str | None = None, uid=Depends(authenticated)):
    with transaction() as db:
        sweep(db)
        args = [uid]
        condition = ""
        if cursor:
            value = decode_cursor(cursor)
            if not isinstance(value, list) or len(value) != 2 or not isinstance(value[0], (int, float)) or not isinstance(value[1], str):
                fail(422, "Invalid history cursor")
            condition = " AND (m.created<? OR (m.created=? AND m.id<?))"
            args.extend([value[0], value[0], value[1]])
        rows = db.execute("SELECT m.id,m.created FROM matches m JOIN participants p ON m.id=p.match_id WHERE p.user_id=?" + condition + " ORDER BY m.created DESC,m.id DESC LIMIT 21", args).fetchall()
        return dict(matches=[match_view(db, uid, r["id"]) for r in rows[:20]], nextCursor=encode_cursor([rows[19]["created"], rows[19]["id"]]) if len(rows) > 20 else None)


@app.get("/v1/leaderboard/{variation}")
def leaderboard(variation: str, cursor: str | None = None, aroundMe: bool = False, uid=Depends(authenticated)):
    if variation not in VARIATIONS:
        fail(404, "Unknown movement")
    with transaction() as db:
        base = "WITH ladder AS (SELECT a.public_id,a.display_name,r.rating,r.games,row_number() OVER (ORDER BY r.rating DESC,a.public_id ASC) position FROM ratings r JOIN accounts a ON a.id=r.user_id WHERE r.variation=? AND r.games>0 AND a.listed=1) "
        mine = account(db, uid)
        my_row = db.execute(base + "SELECT * FROM ladder WHERE public_id=?", (variation, mine["publicID"])).fetchone()
        start = max(0, my_row["position"] - 10) if aroundMe and my_row else 0
        condition, args = "", [variation]
        if cursor and not aroundMe:
            value = decode_cursor(cursor)
            if not isinstance(value, list) or len(value) != 2 or not isinstance(value[0], int) or not isinstance(value[1], str):
                fail(422, "Invalid leaderboard cursor")
            condition = "WHERE rating<? OR (rating=? AND public_id>?) "
            args += [value[0], value[0], value[1]]
        args += [start]
        rows = db.execute(base + "SELECT * FROM ladder " + condition + "ORDER BY rating DESC,public_id ASC LIMIT 21 OFFSET ?", args).fetchall()
        def view(r):
            return dict(publicID=r["public_id"], displayName=r["display_name"], rating=r["rating"], games=r["games"], position=r["position"])
        return dict(rows=[view(r) for r in rows[:20]], me=view(my_row) if my_row else None, nextCursor=encode_cursor([rows[19]["rating"], rows[19]["public_id"]]) if len(rows) > 20 else None)


@app.get("/v1/players/{public_id}")
def player(public_id: str, uid=Depends(authenticated)):
    with transaction() as db:
        a = db.execute("SELECT id,public_id,display_name FROM accounts WHERE public_id=? AND listed=1", (public_id,)).fetchone()
        if not a:
            fail(404, "This player does not share a public Ranked profile")
        return dict(publicID=a["public_id"], displayName=a["display_name"], ratings=[dict(variation=r["variation"], rating=r["rating"], games=r["games"]) for r in db.execute("SELECT * FROM ratings WHERE user_id=? AND games>0 ORDER BY variation", (a["id"],))])
