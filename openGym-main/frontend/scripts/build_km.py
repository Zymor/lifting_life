import json
import os
import re

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
KEYS_PATH = r"C:\Users\Reatanak\.gemini\antigravity\brain\c5f85fdb-cd1d-45f2-a1d2-546f56cb5621\scratch\keys.json"
TH_PATH = r"C:\Users\Reatanak\.gemini\antigravity\brain\c5f85fdb-cd1d-45f2-a1d2-546f56cb5621\scratch\th.json"
OUT_PATH = os.path.join(SCRIPT_DIR, "..", "src", "locales", "km.js")

with open(KEYS_PATH, "r", encoding="utf-8") as f:
    keys = json.load(f)

print(f"Loaded {len(keys)} keys.")
