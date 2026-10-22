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
CREATE TABLE IF NOT EXISTS physique_profiles (
    user_id TEXT PRIMARY KEY REFERENCES accounts(id),
    display_name TEXT NOT NULL DEFAULT 'Athlete',
    country_code TEXT,
    consent TEXT NOT NULL DEFAULT '{"adult":false,"adultMan":false,"rulesAccepted":false,"aiProcessing":false,"opponentSharing":false,"policyVersion":""}',
    listed INTEGER NOT NULL DEFAULT 0,
    rating INTEGER NOT NULL DEFAULT 1000 CHECK(rating BETWEEN 0 AND 5000),
    restricted_reason TEXT,
    restricted_until REAL,
    deleted INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS physique_queue (
    user_id TEXT PRIMARY KEY REFERENCES physique_profiles(user_id),
    created REAL NOT NULL,
    heartbeat REAL NOT NULL,
    policy_key TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS physique_matches (
    id TEXT PRIMARY KEY,
    stage TEXT NOT NULL,
    created REAL NOT NULL,
    start REAL,
    deadline REAL,
    judging_started REAL,
    judging_deadline REAL,
    finalized REAL,
    reason TEXT,
    judge_version TEXT NOT NULL,
    policy_key TEXT NOT NULL,
    winner TEXT,
    explanation TEXT,
    provider_model TEXT,
    judge_claimed INTEGER NOT NULL DEFAULT 0,
    corrected INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS physique_pending ON physique_matches(stage)
    WHERE finalized IS NULL;
CREATE TABLE IF NOT EXISTS physique_participants (
    match_id TEXT NOT NULL REFERENCES physique_matches(id),
    slot TEXT NOT NULL CHECK(slot IN ('a','b')),
    user_id TEXT REFERENCES accounts(id),
    identity TEXT NOT NULL,
    adult_man INTEGER NOT NULL,
    sharing INTEGER NOT NULL DEFAULT 1,
    ready INTEGER NOT NULL DEFAULT 0,
    last_seen REAL NOT NULL,
    submitted INTEGER NOT NULL DEFAULT 0,
    before_rating INTEGER NOT NULL,
    before_games INTEGER NOT NULL,
    sensitivity INTEGER NOT NULL,
    scores TEXT,
    outcome TEXT,
    original_outcome TEXT,
    original_delta INTEGER,
    delta INTEGER,
    after_rating INTEGER,
    after_games INTEGER,
    PRIMARY KEY(match_id,slot),
    UNIQUE(match_id,user_id)
);
CREATE INDEX IF NOT EXISTS physique_history ON physique_participants(user_id,match_id);
CREATE TABLE IF NOT EXISTS physique_active (
    user_id TEXT PRIMARY KEY REFERENCES physique_profiles(user_id),
    match_id TEXT NOT NULL REFERENCES physique_matches(id)
);
CREATE TABLE IF NOT EXISTS physique_starts (
    user_id TEXT NOT NULL REFERENCES physique_profiles(user_id),
    match_id TEXT NOT NULL REFERENCES physique_matches(id),
    at REAL NOT NULL,
    restored INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(user_id,match_id)
);
CREATE INDEX IF NOT EXISTS physique_allowance ON physique_starts(user_id,at);
CREATE TABLE IF NOT EXISTS physique_media (
    id TEXT PRIMARY KEY,
    match_id TEXT NOT NULL REFERENCES physique_matches(id),
    slot TEXT NOT NULL,
    pose TEXT NOT NULL CHECK(pose IN ('front','side','rear')),
    attempts INTEGER NOT NULL,
    status TEXT NOT NULL,
    reason TEXT,
    file_key TEXT,
    digest TEXT,
    created REAL NOT NULL,
    expires REAL NOT NULL,
    UNIQUE(match_id,slot,pose)
);
CREATE TABLE IF NOT EXISTS physique_requests (
    user_id TEXT NOT NULL REFERENCES accounts(id),
    request_id TEXT NOT NULL,
    fingerprint TEXT NOT NULL,
    operation TEXT NOT NULL,
    created REAL NOT NULL,
    status TEXT NOT NULL,
    receipt_id TEXT,
    message TEXT,
    PRIMARY KEY(user_id,request_id)
);
CREATE TABLE IF NOT EXISTS physique_blocks (
    owner TEXT NOT NULL REFERENCES accounts(id),
    target TEXT NOT NULL REFERENCES accounts(id),
    created REAL NOT NULL,
    PRIMARY KEY(owner,target)
);
CREATE TABLE IF NOT EXISTS physique_hides (
    owner TEXT NOT NULL REFERENCES accounts(id),
    media_id TEXT NOT NULL REFERENCES physique_media(id),
    reported INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(owner,media_id)
);
CREATE TABLE IF NOT EXISTS physique_cases (
    id TEXT PRIMARY KEY,
    owner TEXT NOT NULL REFERENCES accounts(id),
    kind TEXT NOT NULL,
    status TEXT NOT NULL,
    summary TEXT NOT NULL,
    category TEXT NOT NULL,
    target TEXT NOT NULL,
    match_id TEXT REFERENCES physique_matches(id),
    parent_id TEXT REFERENCES physique_cases(id),
    created REAL NOT NULL,
    updated REAL NOT NULL,
    closed REAL,
    decision TEXT,
    needs_reply INTEGER NOT NULL DEFAULT 0,
    decision_by TEXT,
    UNIQUE(owner,kind,target)
);
CREATE TABLE IF NOT EXISTS physique_case_messages (
    id TEXT PRIMARY KEY,
    case_id TEXT NOT NULL REFERENCES physique_cases(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    created REAL NOT NULL,
    from_staff INTEGER NOT NULL,
    staff_id TEXT
);
CREATE TABLE IF NOT EXISTS physique_holds (
    case_id TEXT NOT NULL REFERENCES physique_cases(id) ON DELETE CASCADE,
    media_id TEXT NOT NULL REFERENCES physique_media(id),
    file_key TEXT NOT NULL,
    expires REAL NOT NULL,
    PRIMARY KEY(case_id,media_id)
);
CREATE TABLE IF NOT EXISTS physique_privacy (
    id TEXT PRIMARY KEY,
    owner TEXT NOT NULL REFERENCES accounts(id),
    scope TEXT NOT NULL,
    status TEXT NOT NULL,
    created REAL NOT NULL,
    updated REAL NOT NULL,
    detail TEXT NOT NULL,
    retained_reason TEXT
);
CREATE TABLE IF NOT EXISTS physique_corrections (
    id TEXT PRIMARY KEY,
    match_id TEXT NOT NULL UNIQUE REFERENCES physique_matches(id),
    case_id TEXT NOT NULL REFERENCES physique_cases(id),
    staff_id TEXT NOT NULL,
    created REAL NOT NULL,
    reason TEXT NOT NULL,
    original_result TEXT NOT NULL,
    corrected_result TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS physique_rating_events (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES accounts(id),
    match_id TEXT NOT NULL REFERENCES physique_matches(id),
    kind TEXT NOT NULL,
    at REAL NOT NULL,
    delta INTEGER NOT NULL,
    after_rating INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS physique_pages (
    id TEXT PRIMARY KEY,
    owner TEXT NOT NULL REFERENCES accounts(id),
    kind TEXT NOT NULL,
    data TEXT NOT NULL,
    expires REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS physique_staff_requests (
    staff_id TEXT NOT NULL,
    request_id TEXT NOT NULL,
    fingerprint TEXT NOT NULL,
    created REAL NOT NULL,
    PRIMARY KEY(staff_id,request_id)
);
CREATE TABLE IF NOT EXISTS physique_queue_status (
    user_id TEXT PRIMARY KEY REFERENCES physique_profiles(user_id),
    status TEXT NOT NULL,
    updated REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS physique_consent_revisions (
    user_id TEXT PRIMARY KEY REFERENCES physique_profiles(user_id),
    revision REAL NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS physique_original_effect ON physique_rating_events(user_id,match_id,kind);
CREATE INDEX IF NOT EXISTS physique_media_expiry ON physique_media(expires);
CREATE INDEX IF NOT EXISTS physique_cases_owner ON physique_cases(owner,updated DESC);
CREATE INDEX IF NOT EXISTS physique_holds_expiry ON physique_holds(expires);
CREATE TABLE IF NOT EXISTS physique_staff_access (
    id TEXT PRIMARY KEY,
    staff_id TEXT NOT NULL,
    case_id TEXT NOT NULL REFERENCES physique_cases(id) ON DELETE CASCADE,
    kind TEXT NOT NULL,
    created REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS physique_privacy_holds (
    receipt_id TEXT NOT NULL REFERENCES physique_privacy(id) ON DELETE CASCADE,
    media_id TEXT NOT NULL REFERENCES physique_media(id),
    PRIMARY KEY(receipt_id,media_id)
);
PRAGMA user_version = 2;
