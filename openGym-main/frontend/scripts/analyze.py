import json, re

with open(r'C:\Users\Reatanak\.gemini\antigravity\brain\c5f85fdb-cd1d-45f2-a1d2-546f56cb5621\scratch\keys.json', 'r', encoding='utf-8') as f:
    keys = json.load(f)

print(f"Total keys: {len(keys)}")
words = set()
for k in keys:
    for w in k.split():
        words.add(re.sub(r'[^\w]', '', w.lower()))
print(f"Distinct words: {len(words)}")
