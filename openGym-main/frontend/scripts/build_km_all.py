# -*- coding: utf-8 -*-
import json
import os
import re

KEYS_PATH = r"C:\Users\Reatanak\.gemini\antigravity\brain\c5f85fdb-cd1d-45f2-a1d2-546f56cb5621\scratch\keys.json"
OUT_PATH = r"C:\Users\Reatanak\OneDrive\Desktop\i4\codeflutter\Lifting Gym\lifting_life\openGym-main\frontend\src\locales\km.js"

with open(KEYS_PATH, "r", encoding="utf-8") as f:
    keys = json.load(f)

print(f"Translating {len(keys)} keys into Khmer...")

