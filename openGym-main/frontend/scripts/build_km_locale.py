# -*- coding: utf-8 -*-
import json
import os
import re

KEYS_PATH = r"C:\Users\Reatanak\.gemini\antigravity\brain\c5f85fdb-cd1d-45f2-a1d2-546f56cb5621\scratch\keys.json"
OUT_PATH = r"C:\Users\Reatanak\OneDrive\Desktop\i4\codeflutter\Lifting Gym\lifting_life\openGym-main\frontend\src\locales\km.js"

with open(KEYS_PATH, "r", encoding="utf-8") as f:
    keys = json.load(f)

# Base dictionary of translations
# Let's define key vocabulary and full phrase translations
translations = {}

# 1. Direct standard UI terms
translations.update({
    "Confirm": "បញ្ជាក់",
    "Cancel": "បោះបង់",
    "Press back again to exit": "ចុចថយក្រោយម្តងទៀតដើម្បីចាកចេញ",
    "Delete": "លុប",
    "Copy set": "ចម្លងសិត",
    "Save": "រក្សាទុក",
    "Import": "នាំចូល",
    "Discard": "បោះបង់ចោល",
    "All": "ទាំងអស់",
    "Rest": "សម្រាក",
    "On": "បើក",
    "Off": "បិទ",
    "On 🔔": "បើក 🔔",
    "Off 🔕": "បិទ 🔕",
    "Skip": "រំលង",
    "New": "ថ្មី",
    "Log": "កំណត់ត្រា",
    "Goal": "គោលដៅ",
    "Plan": "គម្រោង",
    "Today": "ថ្ងៃនេះ",
    "Home": "ទំព័រដើម",
    "Start": "ចាប់ផ្តើម",
    "Resume": "បន្ត",
    "Stats": "ស្ថិតិ",
    "Exercises": "លំហាត់ប្រាណ",
    "By muscle": "តាមសាច់ដុំ",
    "Explore muscles": "ស្វែងរកតាមសាច់ដុំ",
    "Routines": "កម្មវិធីហាត់ប្រចាំ",
    "Start empty workout": "ចាប់ផ្តើមការហាត់ទទេ",
    "Workout": "ការហាត់ប្រាណ",
    "Finish": "បញ្ចប់",
    "Finish workout": "បញ្ចប់ការហាត់",
    "Finished": "បានបញ្ចប់",
    "Discard workout": "បោះបង់ការហាត់",
    "Resume workout": "បន្តការហាត់ប្រាណ",
    "Add exercise": "បន្ថែមលំហាត់",
    "Add set": "បន្ថែមសិត",
    "Replace": "ជំនួស",
    "Remove": "ដកចេញ",
    "Reorder": "រៀបលំដាប់ឡើងវិញ",
    "Settings": "ការកំណត់",
    "History": "ប្រវត្តិ",
    "Profile": "ប្រវត្តិរូប",
    "Account": "គណនី",
    "Password": "ពាក្យសម្ងាត់",
    "Passkey": "Passkey",
    "Passkeys": "Passkeys",
    "Sign in": "ចូលគណនី",
    "Sign out": "ចាកចេញ",
    "Register": "ចុះឈ្មោះ",
    "Coach": "គ្រូបង្វឹក AI",
    "AI Coach": "គ្រូបង្វឹក AI",
    "Plate calculator": "ម៉ាស៊ីនគណនាបន្ទះដែក",
    "Warmup": "កម្ដៅសាច់ដុំ",
    "Drop set": "ឌ្របសិត",
    "Superset": "ស៊ុបពើសិត",
    "Failure": "អស់កម្លាំង",
    "Reps": "ដង",
    "Weight": "ទម្ងន់",
    "Sets": "សិត",
    "Duration": "រយៈពេល",
    "Distance": "ចម្ងាយ",
    "Calories": "កាឡូរី",
    "Time": "ពេលវេលា",
    "Notes": "កំណត់ចំណាំ",
    "Search": "ស្វែងរក",
    "Filter": "តម្រង",
    "Theme": "រូបរាង",
    "Dark": "ងងឹត",
    "Light": "ភ្លឺ",
    "System": "ប្រព័ន្ធ",
    "Language": "ភាសា",
    "Units": "ឯកតា",
    "Sound": "សំឡេង",
    "Vibration": "រំញ័រ",
    "Backup": "បម្រុងទុក",
    "Restore": "ស្តារឡើងវិញ",
    "Export": "នាំចេញ",
    "Sync": "សមកាលកម្ម",
    "Cloud sync": "ធ្វើសមកាលកម្មពពក"
})

print(f"Base translations count: {len(translations)}")

