PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
CREATE TABLE IF NOT EXISTS accounts (
    id TEXT PRIMARY KEY,
    public_id TEXT NOT NULL UNIQUE,
    login TEXT NOT NULL UNIQUE,
    password TEXT NOT NULL,
    display_name TEXT NOT NULL,
    listed INTEGER NOT NULL DEFAULT 0,
    created REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
    access_hash TEXT PRIMARY KEY,
    refresh_hash TEXT NOT NULL UNIQUE,
    user_id TEXT NOT NULL REFERENCES accounts(id),
    family TEXT NOT NULL,
    access_expires REAL NOT NULL,
    refresh_expires REAL NOT NULL,
    revoked INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS sessions_user ON sessions(user_id);
CREATE TABLE IF NOT EXISTS auth_limits (
    bucket TEXT NOT NULL,
    at REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS auth_limit_bucket ON auth_limits(bucket,at);
CREATE TABLE IF NOT EXISTS ratings (
    user_id TEXT NOT NULL REFERENCES accounts(id),
    variation TEXT NOT NULL,
    rating INTEGER NOT NULL CHECK(rating BETWEEN 0 AND 5000),
    games INTEGER NOT NULL DEFAULT 0,
    policy TEXT NOT NULL DEFAULT 'elo-1',
    PRIMARY KEY(user_id,variation)
);
CREATE INDEX IF NOT EXISTS rating_ladder ON ratings(variation,rating DESC,user_id);
CREATE TABLE IF NOT EXISTS queue (
    user_id TEXT PRIMARY KEY REFERENCES accounts(id),
    variation TEXT NOT NULL,
    rules TEXT NOT NULL,
    rating INTEGER NOT NULL,
    created REAL NOT NULL,
    heartbeat REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS matches (
    id TEXT PRIMARY KEY,
    variation TEXT NOT NULL,
    rules TEXT NOT NULL,
    state TEXT NOT NULL,
    created REAL NOT NULL,
    ready_deadline REAL NOT NULL,
    start REAL,
    end REAL,
    finalized REAL,
    reason TEXT,
    winner TEXT REFERENCES accounts(id),
    revision INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS matches_pending ON matches(state) WHERE state NOT IN ('completed','forfeited','invalid','cancelled');
CREATE TABLE IF NOT EXISTS participants (
    match_id TEXT NOT NULL REFERENCES matches(id),
    user_id TEXT NOT NULL REFERENCES accounts(id),
    nonce TEXT NOT NULL,
    ready INTEGER NOT NULL DEFAULT 0,
    last_seen REAL NOT NULL,
    sequence INTEGER NOT NULL DEFAULT 0,
    tracker TEXT NOT NULL,
    score REAL NOT NULL DEFAULT 0,
    submitted INTEGER NOT NULL DEFAULT 0,
    verification TEXT NOT NULL DEFAULT 'pending',
    before_rating INTEGER,
    after_rating INTEGER,
    PRIMARY KEY(match_id,user_id)
);
CREATE INDEX IF NOT EXISTS participant_history ON participants(user_id,match_id);
CREATE TABLE IF NOT EXISTS active (
    user_id TEXT PRIMARY KEY REFERENCES accounts(id),
    match_id TEXT NOT NULL REFERENCES matches(id)
);
CREATE TABLE IF NOT EXISTS starts (
    user_id TEXT NOT NULL REFERENCES accounts(id),
    match_id TEXT NOT NULL REFERENCES matches(id),
    family TEXT NOT NULL CHECK(family IN ('pushUps','squats')),
    at REAL NOT NULL,
    PRIMARY KEY(user_id,match_id)
);
CREATE INDEX IF NOT EXISTS starts_window ON starts(user_id,family,at);
CREATE TABLE IF NOT EXISTS evidence (
    match_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    sequence INTEGER NOT NULL,
    count INTEGER NOT NULL,
    digest TEXT NOT NULL,
    frames TEXT,
    received REAL NOT NULL,
    PRIMARY KEY(match_id,user_id,sequence),
    FOREIGN KEY(match_id,user_id) REFERENCES participants(match_id,user_id)
);
CREATE INDEX IF NOT EXISTS evidence_retention ON evidence(received) WHERE frames IS NOT NULL;
CREATE TABLE IF NOT EXISTS requests (
    user_id TEXT NOT NULL REFERENCES accounts(id),
    request_id TEXT NOT NULL,
    operation TEXT NOT NULL,
    at REAL NOT NULL,
    PRIMARY KEY(user_id,request_id)
);
CREATE TABLE IF NOT EXISTS cloud_accounts (
    subject TEXT PRIMARY KEY,
    ranked_user_id TEXT UNIQUE REFERENCES accounts(id),
    legacy_linked INTEGER NOT NULL DEFAULT 0,
    deleting INTEGER NOT NULL DEFAULT 0 CHECK(deleting IN (0,1,2)),
    created REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS sync_revision (
    singleton INTEGER PRIMARY KEY CHECK(singleton=1),
    value INTEGER NOT NULL CHECK(value>=0)
);
INSERT OR IGNORE INTO sync_revision VALUES (1,0);
CREATE TABLE IF NOT EXISTS sync_blobs (
    owner TEXT NOT NULL REFERENCES cloud_accounts(subject),
    hash TEXT NOT NULL,
    size INTEGER NOT NULL CHECK(size>0 AND size<=4194304),
    PRIMARY KEY(owner,hash)
);
CREATE TABLE IF NOT EXISTS sync_files (
    owner TEXT NOT NULL REFERENCES cloud_accounts(subject),
    path TEXT NOT NULL,
    revision INTEGER NOT NULL UNIQUE,
    hash TEXT,
    size INTEGER NOT NULL CHECK(size>=0),
    chunks TEXT NOT NULL,
    deleted INTEGER NOT NULL CHECK(deleted IN (0,1)),
    PRIMARY KEY(owner,path)
);
CREATE INDEX IF NOT EXISTS sync_manifest ON sync_files(owner,revision);
CREATE TABLE IF NOT EXISTS sync_commits (
    owner TEXT NOT NULL REFERENCES cloud_accounts(subject),
    request_hash TEXT NOT NULL,
    response TEXT NOT NULL,
    PRIMARY KEY(owner,request_hash)
);
PRAGMA user_version = 2;
