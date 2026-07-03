# Frequently Asked Questions

Short, straight answers about how Detoxo works, what it does with your data, and how to control it. If something here doesn't match what you're seeing, email us at **errorxperts@gmail.com**.

---

## Why does Detoxo need the Accessibility permission?

Detoxo is a reel and short-form-video blocker. To do its job it has to notice the *moment* a Reels / Shorts / infinite-feed screen opens inside another app (Instagram, YouTube, Snapchat, and so on) and act right then. On Android, the only way one app can tell what screen another app is showing is Android's **Accessibility Service**.

Detoxo uses that permission for exactly one purpose: to recognise a short-video feed on screen and pull you out of it. That's also why it's Android-only — there is no equivalent permission on iPhone (see below).

## Does Detoxo read, collect, or upload my data?

No. Detoxo runs **entirely on your device and offline**.

- It does **not** send your browsing, your messages, your app activity, or your reel counts to any server. There is no cloud account, no login, no analytics upload, no crash reporting, and no ad tracking wired into the app.
- The Accessibility permission lets Detoxo *recognise* a reel screen in the moment (it looks for the on-screen elements that make up a video feed). It does **not** read your DMs, capture what you watch, or keep a copy of anything you see.
- Everything Detoxo remembers — your plan, your reel count, your settings, your blocked-events history — is stored **locally on your phone**. Your PIN is kept in your device's secure storage.

In short: Detoxo watches for "is this a reel feed?" so it can block it, and nothing about that ever leaves your phone.

## How does Detoxo actually stop me from scrolling?

When Detoxo detects a short-video feed, it gently pulls you out of it. The standard action is a simple **Back** press — the same as if you'd tapped your phone's back button — which closes the feed and drops you back to the previous screen. (An optional short vibration can confirm it happened.)

Depending on your setup, the action can instead **close the app** or **lock the screen**, but a back-press is the default and the least disruptive.

## What's the difference between Block All, Conscious, One Reel, and Pause?

These are the four ways Detoxo can behave. You pick whichever fits your goal:

| Mode | What it does |
| --- | --- |
| **Block All** | The strict default. Every reel/short you open is closed straight away. |
| **Conscious** | A "earn-as-you-abstain" mode. You build up a small allowance of watch-time by *staying off* reels (about 1 minute banked for every 10 minutes away, up to 10 minutes saved). While you have allowance, reels play; when it runs out, blocking kicks back in until you've earned more. It keeps you honest without a hard wall. |
| **One Reel** | Lets one reel through, then blocks the next — a single-peek release valve instead of an all-or-nothing block. |
| **Pause** | A short, deliberate break. You choose a window (2–10 minutes); during it, everything is allowed. When the timer runs out, blocking automatically returns. |

Tip: with **Conscious**, pausing a video doesn't secretly bank you extra time — the allowance only builds while you're genuinely off short-video feeds.

## How does the reel counter work — and is it separate from blocking?

Yes, the reel counter is **completely separate from blocking**. It runs on its own and simply tallies the short videos you actually watch, so you can see the number even if you never turn blocking on.

- A video only counts **after you've watched it for about 2 seconds** — quick flick-throughs are ignored, so the count reflects real watching, not accidental scrolls.
- It counts reels and shorts, but deliberately **skips** regular feeds, Stories, and statuses (those aren't "reels").
- The count keeps running whether blocking is on, off, or paused. It's on by default because awareness alone tends to change habits.

You can see the number three ways: inside the app, on an optional **floating bubble** that hovers over your screen while you watch, and on an optional **home-screen widget**. The bubble and widget both keep working even if you close the Detoxo app.

## The floating bubble needs "Display over apps" — why?

The little counter bubble floats on top of whatever app you're in, so Android asks for the **Display over apps** permission (sometimes shown as "Draw over other apps") before it can appear. It's optional — if you skip it, counting still works everywhere; you just won't see the bubble. Blocking does not need this permission.

## Will Detoxo drain my battery?

No, the impact is small. Detoxo is built to be light: it only reacts briefly when a screen changes, limits how often it checks each app, and caps how much work it does per check. There's no constant polling and nothing running in the cloud.

You will see a permanent, silent notification ("Detoxo is active") in your tray. That notification is required by Android to keep the blocker alive in the background — it's a status marker, not an alert, and it makes no sound.

## Does Detoxo work on iPhone / iOS?

No — Detoxo is **Android-only**, and this isn't a temporary gap. The whole product depends on Android's Accessibility Service to see a reel feed and press Back. Apple's system deliberately doesn't let one app look inside another app or dismiss its screen, so there's simply no way to build the same reel-level blocking on iPhone. If you open Detoxo on an iPhone you'll see a short screen explaining this rather than broken controls.

## How do I take a break or turn Detoxo off?

- For a **quick break**, use **Pause** — pick 2–10 minutes and everything is allowed until the timer ends, then blocking comes back on its own. This is the recommended way to step away without forgetting to turn protection back on.
- To **turn blocking off entirely**, open **Settings** and switch off **Protection** (the master switch for all detection). If you've set a PIN, Detoxo will ask for it first — that's the intentional speed bump that stops an impulsive "just turn it off."

The reel counter is controlled separately (in the reel counter screen), so you can keep counting even with blocking off.

## I set a PIN and forgot it — how do I get back in?

When you set up the PIN lock, Detoxo asks for a **recovery email**. On the lock screen, tap **"Forgot PIN?"**, confirm a code sent to that email, and you'll be able to set a fresh PIN (your other settings stay intact).

Honest note: in the current offline build, the "email the code" step isn't yet connected to a live mail server (it's a planned addition), so recovery uses a fallback code. If you're locked out and stuck, email **errorxperts@gmail.com** and we'll help you reset.

## How do I uninstall Detoxo?

Uninstall it like any app — **unless** you turned on the optional **Device Admin** protection.

Device Admin is an opt-in feature that stops Detoxo from being uninstalled on impulse (and enables the lock-screen action). If you enabled it, Android won't let you remove the app until you first **remove Detoxo as a device administrator** — you can do that from Detoxo's own settings, or from your phone's *Settings → Security → Device admin apps*. After that, uninstall works normally. Turning off the Accessibility permission (in *Settings → Accessibility*) also stops all blocking immediately.

## Which apps and sites does Detoxo cover?

Detoxo targets the short-video feeds inside popular apps (think Reels, Shorts, and similar infinite-scroll video), plus it can bounce you off blocked websites — including an optional built-in adult-site list — when you browse. It focuses on the *feed*, so the rest of an app (messages, search, posting) keeps working normally.

---

**Related (for the technically curious):**
[../code_docs/03-detection-engine.md](../code_docs/03-detection-engine.md) ·
[../code_docs/05-plans-pause-conscious.md](../code_docs/05-plans-pause-conscious.md) ·
[../code_docs/17-content-counter.md](../code_docs/17-content-counter.md) ·
[../code_docs/15-ios-cross-platform.md](../code_docs/15-ios-cross-platform.md)
