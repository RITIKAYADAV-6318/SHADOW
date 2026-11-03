-- Events are the SOURCE OF TRUTH. attempts / tasks / mastery / reviews / state are
-- projections that can be rebuilt by replaying events.

-- IDENTITY & SETTINGS -------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY,
  name TEXT,
  timezone TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS profile (
  user_id INTEGER PRIMARY KEY REFERENCES users(id),
  goal TEXT,
  target_companies TEXT,
  language TEXT,
  level TEXT,
  daily_hours REAL,
  study_windows_json TEXT,
  strictness TEXT,
  mentor_style TEXT,
  hint_preferences_json TEXT,
  quiet_hours_json TEXT,
  topic_priors_json TEXT,
  mvd_enabled INTEGER NOT NULL DEFAULT 0,
  snooze_until TEXT,
  day_cutoff TEXT NOT NULL DEFAULT '04:00'
);

CREATE TABLE IF NOT EXISTS baseline_metrics (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  recorded_at TEXT NOT NULL,
  problems_per_week REAL,
  active_days_per_week REAL
);

CREATE TABLE IF NOT EXISTS schedule_blocks (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  day_of_week INTEGER NOT NULL,        -- 0=Mon .. 6=Sun
  start TEXT NOT NULL,                 -- 'HH:MM' local
  "end" TEXT NOT NULL,
  label TEXT,
  type TEXT                            -- college | project | volleyball | revision | free ...
);

-- SOURCE OF TRUTH -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY,
  event_id TEXT NOT NULL UNIQUE,       -- idempotency key, generated when the event is created
  user_id INTEGER NOT NULL REFERENCES users(id),
  type TEXT NOT NULL,
  payload_json TEXT NOT NULL DEFAULT '{}',
  source TEXT NOT NULL,                -- extension | web | worker | system | import
  ts TEXT NOT NULL                     -- UTC, fixed format YYYY-MM-DDTHH:MM:SS.mmmZ (see backend/timeutil.py)
);
CREATE INDEX IF NOT EXISTS idx_events_user_ts ON events(user_id, ts);
CREATE INDEX IF NOT EXISTS idx_events_type ON events(type);

-- STATIC KNOWLEDGE ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS problems (
  id INTEGER PRIMARY KEY,
  platform TEXT NOT NULL DEFAULT 'leetcode',
  slug TEXT NOT NULL UNIQUE,
  title TEXT,
  difficulty TEXT,
  lc_tags_json TEXT,
  list_topic_raw TEXT,                 -- the label exactly as the imported list wrote it (kept even if it can't be mapped)
  list_topic TEXT,                     -- canonical topic id (e.g. 't_trees') mapped from the list label via data/topics.json
  pattern TEXT,                        -- finer pattern, nullable
  pattern_key TEXT,                    -- = pattern id if set, else the canonical topic id (mastery key)
  prerequisites_json TEXT,
  key_observation TEXT,
  common_traps_json TEXT,
  similar_json TEXT,
  interview_freq TEXT,                 -- manual only, never AI-generated
  source_list TEXT,
  list_order INTEGER,
  enrichment_status TEXT NOT NULL DEFAULT 'none',   -- none | ai_draft | reviewed
  enriched_at TEXT,
  my_notes TEXT
);
CREATE INDEX IF NOT EXISTS idx_problems_pattern_key ON problems(pattern_key);

-- PROJECTIONS (rebuildable from events) -------------------------------------
CREATE TABLE IF NOT EXISTS attempts (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  problem_id INTEGER NOT NULL REFERENCES problems(id),
  source TEXT NOT NULL DEFAULT 'live', -- live | import
  started_at TEXT NOT NULL,
  ended_at TEXT,
  active_time_sec INTEGER NOT NULL DEFAULT 0,
  solved INTEGER NOT NULL DEFAULT 0,   -- 1 iff it contains a SUBMISSION_ACCEPTED
  accepted_submissions INTEGER NOT NULL DEFAULT 0,
  rejected_submissions INTEGER NOT NULL DEFAULT 0,
  entry_hint_level INTEGER,
  max_hint_level INTEGER,
  language TEXT,
  is_revisit INTEGER NOT NULL DEFAULT 0,
  is_junk INTEGER NOT NULL DEFAULT 0,
  notes TEXT
);
CREATE INDEX IF NOT EXISTS idx_attempts_user_problem ON attempts(user_id, problem_id);

CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY,
  task_uid TEXT NOT NULL UNIQUE,       -- stable id made by the planner; carried in TASK_ASSIGNED events and `supersedes` lists
  user_id INTEGER NOT NULL REFERENCES users(id),
  date TEXT NOT NULL,                  -- local 'day' (04:00 cutoff)
  kind TEXT NOT NULL,                  -- revision | warmup | main | review | reflection
  problem_id INTEGER REFERENCES problems(id),
  topic TEXT,
  status TEXT NOT NULL DEFAULT 'planned',
  planned_start TEXT,
  planned_minutes INTEGER,
  reason TEXT,
  superseded INTEGER NOT NULL DEFAULT 0   -- restored from TASK_ASSIGNED events on rebuild
);

CREATE TABLE IF NOT EXISTS mastery (
  user_id INTEGER NOT NULL REFERENCES users(id),
  pattern_key TEXT NOT NULL,
  recognition REAL NOT NULL DEFAULT 0.5,
  implementation REAL NOT NULL DEFAULT 0.5,
  complexity REAL NOT NULL DEFAULT 0.5,
  edge_cases REAL NOT NULL DEFAULT 0.5,
  independence REAL NOT NULL DEFAULT 0.5,
  retention REAL NOT NULL DEFAULT 0.5,
  retention_has_data INTEGER NOT NULL DEFAULT 0,
  composite REAL,
  attempts_count INTEGER NOT NULL DEFAULT 0,   -- first-time, non-junk LIVE attempts only
  updated_at TEXT,
  PRIMARY KEY (user_id, pattern_key)
);

CREATE TABLE IF NOT EXISTS reviews (
  user_id INTEGER NOT NULL REFERENCES users(id),
  problem_id INTEGER NOT NULL REFERENCES problems(id),
  stage INTEGER NOT NULL DEFAULT 0,    -- 0..4 = 1,3,7,21,60 days
  status TEXT NOT NULL DEFAULT 'active',  -- active | retired
  next_review_at TEXT,
  last_result TEXT,
  source TEXT NOT NULL DEFAULT 'live', -- live | import
  updated_at TEXT,
  PRIMARY KEY (user_id, problem_id)
);

CREATE TABLE IF NOT EXISTS state_snapshot (
  user_id INTEGER NOT NULL REFERENCES users(id),
  ts TEXT NOT NULL,
  state_json TEXT NOT NULL
);

-- OTHER ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS study_sessions (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  started_at TEXT NOT NULL,
  ended_at TEXT,
  focus_minutes REAL,
  notes TEXT
);

CREATE TABLE IF NOT EXISTS memories (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  kind TEXT NOT NULL,                  -- episodic | learning | preference | procedural
  content TEXT NOT NULL,
  importance INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  last_used_at TEXT
);

CREATE TABLE IF NOT EXISTS interventions (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  ts TEXT NOT NULL,
  kind TEXT NOT NULL,
  trigger_event TEXT,
  message TEXT,
  user_response TEXT,
  outcome TEXT
);

CREATE TABLE IF NOT EXISTS notifications (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  ts TEXT NOT NULL,
  type TEXT NOT NULL,
  message TEXT,
  delivered INTEGER NOT NULL DEFAULT 0,
  acted_on INTEGER NOT NULL DEFAULT 0,   -- session/problem started within 30 min
  snoozed INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS private_notes (   -- NEVER sent to the LLM
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  ts TEXT NOT NULL,
  content TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS llm_calls (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL DEFAULT 1 REFERENCES users(id),
  ts TEXT NOT NULL,
  purpose TEXT,
  tokens_in INTEGER,
  tokens_out INTEGER,
  cached INTEGER NOT NULL DEFAULT 0,
  status TEXT
);
