"""Reference model of the Detoxo home widgets: the normative spec of every value
a face shows and of how a stored IM-02 payload parses. The Kotlin
(widget/WidgetModel.kt, widget/WidgetPayload.kt) and Dart
(home_content_counter/domain/widget_model.dart, entities/widget_payload.dart)
models are both tested against the vectors it writes; the rules are described in
docs/code_docs/17-content-counter.md section 5.2.

    python3 tool/home_widget/ref_model.py

rewrites test/fixtures/home_widget_cases.json (model vectors) and
test/fixtures/home_widget_payloads.json (parse vectors). Change a rule here
first, regenerate, then make both models pass. The rule numbers (tier step,
stale minutes, ...) are read from the "rule" group of tool/home_widget/tokens.json,
the same source as Kotlin WidgetTokens and Dart WidgetRules. Standard library only."""
import json, math
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RULE = {r["name"]: r["value"] for r in json.loads((ROOT / "tool/home_widget/tokens.json").read_text())["rule"]}
TIER_STEP, MAX_TIER, SEGMENTS = RULE["tier-step"], RULE["max-tier"], RULE["segment-count"]
MAX_LIMIT_MINUTES = RULE["max-limit-minutes"]

STAGES = ["Blooming", "Happy", "Thirsty", "Wilting", "Withering", "Leafless"]
HEALTH = [100, 90, 70, 50, 25, 0]
FAMILIES = ["COUNT", "NEXT_COLOUR", "TIME_LIMIT", "RHYTHM", "BONSAI", "BENTO"]
SIZES = ["SMALL", "MEDIUM", "LARGE"]
STALE_MS = RULE["stale-minutes"] * 60 * 1000
DAY_MS = 86400000

def hm(sec):
    m = max(0, int(sec)) // 60
    h, mm = divmod(m, 60)
    if h == 0: return f"{mm}m"
    if mm == 0: return f"{h}h"
    return f"{h}h {mm}m"

def count_text(n): return "999+" if n > 999 else str(n)
def reels_display(n): return "1 reel" if n == 1 else f"{count_text(n)} reels"   # on the widget (DS-09 cap)
def reels_spoken(n): return "1 reel" if n == 1 else f"{n} reels"               # TalkBack: the real number
def minutes_spoken(m): return "1 minute" if m == 1 else f"{m} minutes"

def hour_label(h, use24):
    if use24: return f"{h:02d}:00"
    if h == 0: return "12 AM"
    if h < 12: return f"{h} AM"
    if h == 12: return "12 PM"
    return f"{h - 12} PM"

def clock_label(ms, off, use24):
    mod = ((ms + off * 60000) // 60000) % 1440
    h, m = divmod(mod, 60)
    if use24: return f"{h:02d}:{m:02d}"
    hh = 12 if h % 12 == 0 else h % 12
    return f"{hh}:{m:02d} {'AM' if h < 12 else 'PM'}"

def local_day(ms, off): return (ms + off * 60000) // DAY_MS

def model(p, now, off, use24, uoff):
    """p is a parsed payload; off is the UTC offset now, uoff the offset at updated_at (DST)."""
    same_day = local_day(p["updated_at"], uoff) == local_day(now, off)
    n = p["reel_count"] if same_day else 0
    watch = p["watch_seconds"] if same_day else 0
    hourly = p["hourly_seconds"] if same_day else [0] * 24
    tier = p["reel_tier"] if same_day else 0
    limit = max(0, min(MAX_LIMIT_MINUTES, p["limit_minutes"])) * 60  # also for a payload built in code
    has_limit = limit > 0
    final = tier == MAX_TIER
    over = has_limit and watch > limit
    stale = p["updated_at"] > 0 and now - p["updated_at"] > STALE_MS
    tracking_off = not p["tracking_enabled"]
    to_next = (n // TIER_STEP + 1) * TIER_STEP - n
    ring = 0 if n == 0 else (100 if final else n % TIER_STEP)
    seg = 0 if not has_limit else max(0, min(SEGMENTS, math.ceil(watch / limit * SEGMENTS - 1e-6)))
    bars = [min(1.0, max(0.04, h / 1800.0)) for h in hourly]
    mx = max(hourly)
    peak = -1 if mx <= 0 else hourly.index(mx)
    time = hm(watch)
    stage, health = STAGES[tier], HEALTH[tier]
    note = "Turn on tracking" if tracking_off else (
        f"Updated {clock_label(p['updated_at'], uoff, use24)}" if stale else None)

    def describe(fam, size):
        if fam == "COUNT" or (fam == "BENTO" and size == "SMALL"):
            base = f"{reels_spoken(n)} today, {time} watched"
        elif fam in ("NEXT_COLOUR", "BENTO"):
            base = (f"{reels_spoken(n)} today, final colour reached" if final
                    else f"{reels_spoken(n)} today, {reels_spoken(to_next)} to the next colour")
        elif fam == "TIME_LIMIT":
            if not has_limit: base = f"{time} watched today, no daily limit set"
            elif over: base = f"{time} watched, {hm(watch - limit)} over the {hm(limit)} limit"
            else: base = f"{time} watched, {hm(limit - watch)} left of the {hm(limit)} limit"
        elif fam == "RHYTHM":
            base = (f"{time} watched today" if peak < 0 else
                    f"{time} watched today, peak at {hour_label(peak, use24)} with {minutes_spoken(hourly[peak] // 60)}")
        else:  # BONSAI
            base = f"Bonsai is {stage}, health {health}%, {reels_spoken(n)} today"
        if tracking_off: return base + ", tracking is off"
        if stale: return base + f", updated {clock_label(p['updated_at'], uoff, use24)}"
        return base

    return {
        "tier": tier, "empty": n == 0, "final": final, "over": over, "stale": stale,
        "trackingOff": tracking_off, "hasLimit": has_limit,
        "countText": count_text(n), "time": time, "toNext": to_next, "ringPct": ring,
        "segmentsOn": seg, "bars": bars, "peakHour": peak,
        "peakLabel": "No peak yet" if peak < 0 else f"Peak {hour_label(peak, use24)}",
        "peakValue": "0m" if peak < 0 else f"{hourly[peak] // 60}m",
        "tierChip": "Empty" if tier == 0 else f"Tier {tier}",
        "reelsChip": reels_display(n),
        "todayShort": "No reels" if n == 0 else "Today",
        "todayLong": "No reels yet" if n == 0 else "Reels today",
        "nextShort": "No reels yet" if n == 0 else ("Final colour" if final else f"{to_next} to next"),
        "nextLong": "No reels yet" if n == 0 else ("Final colour reached" if final else f"{reels_display(to_next)} to next colour"),
        "nextLabel": "First reel starts tier 1" if n == 0 else ("Final colour reached" if final else "Next colour in"),
        "nextValue": reels_display(n) if final else reels_display(to_next),
        "leftBig": time if not has_limit else (f"+{hm(watch - limit)}" if over else hm(limit - watch)),
        "limitLabel": "No daily limit" if not has_limit else (f"Over {hm(limit)}" if over else f"Left of {hm(limit)}"),
        "bonsaiStage": stage, "bonsaiHealth": health, "stageHealth": f"{stage} · {health}%",
        "bentoNextLabel": "Starts at" if n == 0 else ("Final colour" if final else "Next colour"),
        "bentoNextValue": "1 reel" if n == 0 else (count_text(n) if final else reels_display(to_next)),
        "note": note,
        "describe": {f"{f}:{s}": describe(f, s) for f in FAMILIES for s in SIZES},
    }

def tier_of(n): return 0 if n <= 0 else min(MAX_TIER, n // TIER_STEP + 1)

# ── Plan (EVO-073) ─────────────────────────────────────────────────────────────
# The Plan widget reads the engine's plan live from ConfigStore at every draw; it is
# NOT part of the IM-02 payload (still nine keys). Inputs are ConfigStore's values
# verbatim: `plan` is the stored wire token (CURIOUS is Conscious's, and never reaches
# the copy), the pause end in epoch ms, the One Reel / Unblock allowance and use, the
# "Blocking active" switch, and whether the accessibility service is running.

MAX_ALLOWANCE = 20  # ConfigStore.reelAllowance's range is 1..20

def plan_model(s, now, off, use24):
    allowance = max(1, min(MAX_ALLOWANCE, s["reelAllowance"]))  # also for a state built in code
    left = allowance - max(0, min(allowance, s["reelsConsumed"]))
    spent = left == 0
    if not s["serviceOn"]: kind = "SERVICE_OFF"
    elif not s["blockingOn"]: kind = "BLOCKING_OFF"
    elif now < s["pauseUntil"]: kind = "PAUSED"
    elif s["plan"] == "CURIOUS": kind = "CONSCIOUS"
    elif s["plan"] == "ONE_REEL": kind = "ONE_REEL" if allowance == 1 else "UNBLOCK"
    else: kind = "BLOCK_ALL"  # BLOCK_ALL, the legacy PAUSED, anything unknown: every reel blocked
    # Whole minutes left, floored (agrees with the floored "Back on at" clock), never 0.
    mins = max(1, (s["pauseUntil"] - now) // 60000) if kind == "PAUSED" else 0
    left_time = hm(mins * 60)
    until = clock_label(s["pauseUntil"], off, use24)
    title = {"SERVICE_OFF": "Off", "BLOCKING_OFF": "Off", "PAUSED": "Paused", "CONSCIOUS": "Conscious",
             "ONE_REEL": "One Reel", "UNBLOCK": "Unblock", "BLOCK_ALL": "Block All"}[kind]
    of = f"{left} of {allowance}"
    short, long_, desc = {
        "SERVICE_OFF": ("Turn on blocking", "Turn on Accessibility to block",
                        "Blocking is off, turn on Accessibility for Detoxo"),
        "BLOCKING_OFF": ("Blocking off", "Blocking is switched off", "Blocking is switched off"),
        "PAUSED": ("Reels allowed", f"Back on at {until}",
                   f"Paused, reels allowed for {minutes_spoken(mins)}, blocking returns at {until}"),
        "CONSCIOUS": ("Earn reel time", "Earn reel time by staying off",
                      f"{title} is on, earn reel time by staying off"),
        "BLOCK_ALL": ("Reels blocked", "Every reel is blocked", f"{title} is on, every reel is blocked"),
        "ONE_REEL": ("1 reel allowed", "1 reel allowed, then blocked",
                     f"{title} is on, 1 reel allowed, then blocked"),
        "UNBLOCK": ("Reels left", "Reels left, then blocked", f"{title} is on, {of} reels left"),
    }[kind]
    reels = kind in ("ONE_REEL", "UNBLOCK")
    if reels and spent:
        short, long_, desc = "Reels blocked", "Used, reels blocked again", f"{title} used, reels are blocked again"
    counted = kind == "UNBLOCK" and not spent
    return {
        "planTitle": title,
        "planLabelShort": short,
        "planLabelLong": long_,
        "planValueShort": left_time if kind == "PAUSED" else (of if counted else ""),
        "planValueLong": f"{left_time} left" if kind == "PAUSED" else (of if counted else ""),
        "planClock": kind == "PAUSED",
        "planRingPct": 100 if kind in ("BLOCK_ALL", "CONSCIOUS")
                       else ((allowance - left) * 100 // allowance if reels else 0),
        "planRingText": {"BLOCK_ALL": "On", "CONSCIOUS": "On", "SERVICE_OFF": "Off",
                         "BLOCKING_OFF": "Off", "PAUSED": left_time}.get(kind, str(left)),
        "planDescription": desc,
    }

# ── IM-02 parse ────────────────────────────────────────────────────────────────

EMPTY = {"reel_count": 0, "watch_seconds": 0, "reel_tier": 0, "hourly_seconds": [0] * 24,
         "limit_minutes": 0, "theme": "system", "reduce_motion": False, "updated_at": 0,
         "tracking_enabled": True}
INT_MAX, LONG_MAX = 2**31 - 1, 2**63 - 1

def is_num(v): return isinstance(v, (int, float)) and not isinstance(v, bool)  # JSON true is no number

def whole(v, hi=INT_MAX):
    """A JSON number truncated toward zero, clamped to 0..hi; anything else is 0."""
    return max(0, min(hi, int(v))) if is_num(v) else 0

def parse(raw):
    try:
        o = json.loads(raw)
    except ValueError:
        return EMPTY
    if not isinstance(o, dict): return EMPTY
    hours = o.get("hourly_seconds")
    theme = o.get("theme").lower() if isinstance(o.get("theme"), str) else ""
    flag = lambda k, d: o[k] if isinstance(o.get(k), bool) else d
    return {
        "reel_count": whole(o.get("reel_count")),
        "watch_seconds": whole(o.get("watch_seconds")),
        "reel_tier": whole(o.get("reel_tier"), MAX_TIER),
        "hourly_seconds": ([whole(h, 3600) for h in hours]
                           if isinstance(hours, list) and len(hours) == 24 and all(map(is_num, hours))
                           else [0] * 24),
        "limit_minutes": whole(o.get("limit_minutes"), MAX_LIMIT_MINUTES),
        "theme": theme if theme in ("light", "dark") else "system",
        "reduce_motion": flag("reduce_motion", False),
        "updated_at": whole(o.get("updated_at"), LONG_MAX),
        "tracking_enabled": flag("tracking_enabled", True),
    }

# ── Vectors ────────────────────────────────────────────────────────────────────

NOW = int(datetime(2026, 10, 10, 21, 40, tzinfo=timezone.utc).timestamp() * 1000)
PROFILE = [3, 1, 0, 0, 0, 0, 0, 1, 2, 1, 0, 1, 5, 2, 1, 0, 1, 2, 2, 3, 6, 6, 11, 24]

def spread(watch):
    # Realistic buckets: proportional to the design profile, an hour never holds more than 3600 s;
    # whatever does not fit spills into the earlier hours (latest first).
    tot = sum(PROFILE)
    raw = [int(watch * p / tot + 0.5) for p in PROFILE]
    spill = 0
    for i in range(23, -1, -1):
        v = raw[i] + spill
        raw[i], spill = min(3600, v), max(0, v - 3600)
    return raw

def payload(n, watch, limit_min, *, hourly=None, updated=NOW, tracking=True, theme="system", rm=False, tier=None):
    return {"reel_count": n, "watch_seconds": watch, "reel_tier": tier_of(n) if tier is None else tier,
            "hourly_seconds": spread(watch) if hourly is None else hourly, "limit_minutes": limit_min,
            "theme": theme, "reduce_motion": rm, "updated_at": updated, "tracking_enabled": tracking}

def utc(*a): return int(datetime(*a, tzinfo=timezone.utc).timestamp() * 1000)

MIN = 60000
# Europe/London DST 2026: autumn back at 01:00 UTC on 25 Oct, spring forward at 01:00 UTC on 29 Mar.
AUTUMN_NOW, AUTUMN_UPDATED = utc(2026, 10, 25, 1, 20), utc(2026, 10, 24, 23, 30)  # 01:20 GMT; 00:30 BST
SPRING_NOW, SPRING_UPDATED = utc(2026, 3, 29, 1, 10), utc(2026, 3, 28, 23, 30)    # 02:10 BST; 23:30 GMT
# (name, payload, zoneOffsetMin, use24h[, nowMs, updatedZoneOffsetMin])
cases = [
    ("empty_missing_payload", payload(0, 0, 0, hourly=[0] * 24, updated=0), 0, False),
    ("empty_today", payload(0, 0, 0, hourly=[0] * 24), 0, False),
    ("first_reel", payload(1, 28, 90, hourly=[0] * 21 + [28, 0, 0]), 0, False),
    ("tier1_47", payload(47, 1316, 120), 0, False),
    ("one_to_next_99", payload(99, 2772, 120), 0, False),
    ("exact_100", payload(100, 2800, 120), 0, False),
    ("tier2_152", payload(152, 4256, 120), 0, False),
    ("tier3_238", payload(238, 6664, 120), 0, True),
    ("over_341", payload(341, 9548, 120), 0, False),
    ("final_467", payload(467, 13076, 120, theme="dark", rm=True), 0, False),
    ("cap_1000_doomscroll_30m", payload(1000, 28000, 30), 0, False),
    ("no_limit_45m", payload(152, 2700, 0), 0, False),
    ("limit_exact", payload(150, 7200, 120), 0, False),
    ("stale_12h", payload(152, 4256, 120, updated=NOW - 61 * MIN), 0, False),
    ("stale_24h", payload(152, 4256, 120, updated=NOW - 61 * MIN), 0, True),
    ("tracking_off_beats_stale", payload(152, 4256, 120, updated=NOW - 120 * MIN, tracking=False), 0, False),
    ("yesterday_is_empty", payload(238, 6664, 120, updated=NOW - 22 * 60 * MIN), 0, False),
    ("ist_stale_same_local_day", payload(152, 4256, 120, updated=NOW - 65 * MIN), 330, False),
    ("peak_tie_earliest_24h", payload(80, 1800, 60, hourly=[0] * 9 + [600] + [0] * 3 + [600] + [0] * 10), 0, True),
    ("limit_past_a_day_clamps", payload(152, 4256, INT_MAX), 0, False),
    # Same local day at updated_at's own offset (+60); the current one (0) would call it yesterday.
    ("dst_autumn_stale_same_day", payload(152, 4256, 120, updated=AUTUMN_UPDATED), 0, False, AUTUMN_NOW, 60),
    # Yesterday at updated_at's own offset (0); the current one (+60) would call it today.
    ("dst_spring_yesterday_is_empty", payload(238, 6664, 120, updated=SPRING_UPDATED), 60, False, SPRING_NOW, 0),
]

def case(name, p, off, use24, now=NOW, uoff=None):
    uoff = off if uoff is None else uoff
    return {"name": name, "payload": p, "nowMs": now, "zoneOffsetMin": off, "updatedZoneOffsetMin": uoff,
            "use24h": use24, "expected": model(parse(json.dumps(p)), now, off, use24, uoff)}

# The stored / transported text for each parse vector; `expected` is parse(raw).
raws = [
    ("valid_full", json.dumps({
        "reel_count": 152, "watch_seconds": 4256, "reel_tier": 2,
        "hourly_seconds": [174, 58, 0, 0, 0, 0, 0, 58, 117, 58, 0, 58, 292, 117, 58, 0, 58, 117, 117, 175, 350, 350, 641, 1399],
        "limit_minutes": 120, "theme": "light", "reduce_motion": True, "updated_at": NOW, "tracking_enabled": False})),
    ("blank", ""),
    ("not_json", "not json"),
    ("array", "[]"),
    ("null", "null"),
    ("count_as_string", json.dumps({"reel_count": "12"})),
    ("float_truncates_negative_clamps", json.dumps({"reel_count": 12.7, "watch_seconds": -5})),
    ("tier_clamped_high", json.dumps({"reel_tier": 9})),
    ("tier_clamped_low", json.dumps({"reel_tier": -2})),
    ("hourly_wrong_length", json.dumps({"hourly_seconds": [1, 2, 3]})),
    ("hourly_buckets_clamped", json.dumps({"hourly_seconds": [0, 0, 0, 5000, -3, 1.9] + [0] * 18})),
    ("hourly_non_number", json.dumps({"hourly_seconds": [0] * 23 + ["x"]})),
    ("theme_case_insensitive", json.dumps({"theme": "DARK"})),
    ("theme_unknown", json.dumps({"theme": "blue"})),
    ("bools_wrong_type", json.dumps({"tracking_enabled": "yes", "reduce_motion": 1})),
    ("limit_and_time", json.dumps({"limit_minutes": 30, "updated_at": NOW})),
    ("limit_clamped_to_a_day", json.dumps({"limit_minutes": 1441})),
    ("limit_int_max", json.dumps({"limit_minutes": INT_MAX})),
    ("limit_negative", json.dumps({"limit_minutes": -30})),
]

def plan(p="BLOCK_ALL", until=0, allowance=1, used=0, blocking=True, service=True):
    return {"plan": p, "pauseUntil": until, "reelAllowance": allowance, "reelsConsumed": used,
            "blockingOn": blocking, "serviceOn": service}

# (name, PlanState, zoneOffsetMin, use24h) — all at NOW
plan_cases = [
    ("demo_block_all", plan(), 0, False),
    ("conscious", plan("CURIOUS"), 0, False),
    ("one_reel_unused", plan("ONE_REEL"), 0, False),
    ("one_reel_used", plan("ONE_REEL", used=1), 0, False),
    ("unblock_3_of_5", plan("ONE_REEL", allowance=5, used=2), 0, False),
    ("unblock_spent", plan("ONE_REEL", allowance=5, used=5), 0, False),
    ("unblock_overcount_clamps", plan("ONE_REEL", allowance=5, used=9), 0, False),
    ("one_reel_zero_allowance_clamps", plan("ONE_REEL", allowance=0), 0, False),
    ("paused_4m", plan(until=NOW + 4 * MIN), 0, False),
    ("paused_partial_minute_floors", plan(until=NOW + 3 * MIN + 30000), 0, False),
    ("paused_last_seconds_read_1m", plan(until=NOW + 1000), 0, False),
    ("pause_ended_reads_base", plan("CURIOUS", until=NOW), 0, False),
    ("paused_ist_24h", plan(until=NOW + 4 * MIN), 330, True),
    ("pause_beats_conscious", plan("CURIOUS", until=NOW + 10 * MIN), 0, False),
    ("blocking_off_beats_pause", plan(until=NOW + 4 * MIN, blocking=False), 0, False),
    ("service_off_beats_all", plan(blocking=False, service=False), 0, False),
    ("legacy_paused_token_is_block_all", plan("PAUSED"), 0, False),
    ("unknown_token_is_block_all", plan(""), 0, False),
]

def write(name, out):
    with open(ROOT / "test" / "fixtures" / name, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)

write("home_widget_cases.json", {
    "about": "Shared test vectors for the home-widget model (Kotlin WidgetModelTest + Dart home_widget_model_test). "
             "GENERATED by tool/home_widget/ref_model.py (python3 tool/home_widget/ref_model.py); do not edit by hand. "
             "Both models must reproduce `expected` exactly (bars within 1e-9) from the payload as parsed. "
             "Inputs: IM-02 payload + nowMs + zoneOffsetMin (now) + updatedZoneOffsetMin (at updated_at) + use24h.",
    "cases": [case(*c) for c in cases],
})
write("home_widget_payloads.json", {
    "about": "Shared parse vectors for the IM-02 widget payload (Kotlin WidgetPayloadTest + Dart home_widget_payload_test). "
             "GENERATED by tool/home_widget/ref_model.py; do not edit by hand. "
             "`raw` is the stored/transported JSON text; `expected` is the parsed payload. Rules: not a JSON object -> Empty; "
             f"per key: wrong type/missing -> default; ints truncate toward zero and floor at 0; reel_tier clamps 0..{MAX_TIER}; "
             f"limit_minutes clamps 0..{MAX_LIMIT_MINUTES}; "
             "hourly_seconds must be exactly 24 numbers (else all zeros), each bucket clamped to 0..3600; theme is "
             "case-insensitive system|light|dark (else system); reduce_motion defaults false; tracking_enabled defaults true.",
    "empty": EMPTY,
    "cases": [{"name": name, "raw": raw, "expected": parse(raw)} for (name, raw) in raws],
})
write("home_widget_plan_cases.json", {
    "about": "Shared test vectors for the Plan widget (EVO-073): Kotlin WidgetModelTest + Dart "
             "home_widget_model_test. GENERATED by tool/home_widget/ref_model.py; do not edit by hand. "
             "Input: a PlanState (ConfigStore's plan wire token verbatim, pauseUntil, reelAllowance, "
             "reelsConsumed, blockingOn = masterEnabled, serviceOn = the accessibility service runs) + nowMs "
             "+ zoneOffsetMin + use24h; the payload is Empty. Both models must reproduce `expected` exactly.",
    "cases": [{"name": n, "state": s, "nowMs": NOW, "zoneOffsetMin": off, "use24h": u,
               "expected": plan_model(s, NOW, off, u)} for (n, s, off, u) in plan_cases],
})
print("cases:", len(cases), "payload vectors:", len(raws), "plan cases:", len(plan_cases), "now:", NOW)
