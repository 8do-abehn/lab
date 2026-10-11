"""Set one Open WebUI config key in its database, only if it differs.

Open WebUI copies env values into its database on first start only. After
that the stored value wins, so changing OLLAMA_BASE_URLS in compose alone
changes nothing on an existing install.

Usage (script on stdin): docker exec -i <container> python3 - KEY JSON_VALUE
Prints "changed" or "unchanged".
"""
import json
import sqlite3
import sys
import time

DB = "/app/backend/data/webui.db"

key, value = sys.argv[1], json.loads(sys.argv[2])
db = sqlite3.connect(DB)
row = db.execute("SELECT value FROM config WHERE key = ?", (key,)).fetchone()
if row is not None and json.loads(row[0]) == value:
    print("unchanged")
    sys.exit(0)

db.execute(
    "INSERT INTO config (key, value, updated_at) VALUES (?, ?, ?) "
    "ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at",
    (key, json.dumps(value), int(time.time())),
)
db.commit()
print("changed")
