-- D1 schema for jarvis-telemetry: anonymous per-install crash/error
-- reports and a small set of admin-settable remote overrides. Never
-- stores chat message content — only technical error data (see
-- worker/ai-proxy.js's /report-error handler).

CREATE TABLE IF NOT EXISTS installs (
  install_id TEXT PRIMARY KEY,
  first_seen INTEGER NOT NULL,
  last_seen INTEGER NOT NULL,
  app_version TEXT,
  platform TEXT
);

CREATE TABLE IF NOT EXISTS error_reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  install_id TEXT NOT NULL,
  level TEXT NOT NULL,
  source TEXT NOT NULL,
  message TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

-- One row per install; force_local_ai_enabled is NULL when the admin
-- hasn't set an override (client keeps its own local setting), or 0/1
-- when the admin has forced a value remotely.
CREATE TABLE IF NOT EXISTS remote_overrides (
  install_id TEXT PRIMARY KEY,
  force_local_ai_enabled INTEGER,
  updated_at INTEGER NOT NULL
);
