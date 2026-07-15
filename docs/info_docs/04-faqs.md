# Frequently Asked Questions

Short, straight answers about how Detoxo works, what it does with your data, and how to control it. If something here doesn't match what you're seeing, email us at **errorxperts@gmail.com**.

---

## Why does Detoxo need the Accessibility permission?

Detoxo is a reel and short-form-video blocker. To do its job it has to notice the *moment* a Reels / Shorts / infinite-feed screen opens inside another app (Instagram, YouTube, Snapchat, and so on) and act right then. On Android, the only way one app can tell what screen another app is showing is Android's **Accessibility Service**.

Detoxo uses that permission for exactly one purpose: to recognise a short-video feed on screen and pull you out of it. That's also why it's Android-only — there is no equivalent permission on iPhone (see below).

## Does Detoxo read, collect, or upload my data?

Your **content** stays private — what you watch, browse, and type never leaves your phone. Detoxo does send a small amount of **anonymous, aggregated** usage and crash data (via Google Firebase) so we can fix bugs and improve the app.

- **Never leaves your phone:** the sites and apps you open, the reels you watch, your messages, your blocked-events history, your installed-app list, your PIN, and your recovery email. The Accessibility permission only *recognises* a reel feed in the moment to block it — it doesn't capture or upload what's on your screen, and your PIN lives in your device's secure storage.
- **Anonymous diagnostics we do collect:** which screens you open, when you change plan or toggle protection, how often blocking fires (by app *category* — e.g. "YouTube" — never the specific video or URL), rough reel-count totals, crash reports, and performance timings. This is linked to a **random ID** generated on your device — not to your name, email, or an account (there is no account or login).
- **Blocked websites stay private:** when Detoxo bounces you off a site, it records only *that a block happened* — never which site.
- **No ads, no ad tracking, and we don't sell your data.**

In short: Detoxo keeps what you *see and do* private, and shares only anonymous "how the app is used / did it crash" signals to make it better. (A switch to turn diagnostics off is planned.)

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

## How does Detoxo measure my daily "screen time"?

The ring on your home screen shows how much time you've spent today in the social apps Detoxo watches, filling toward your daily limit. That time is measured **entirely on your device**, using the **same Accessibility permission** the blocker already uses — there's **no extra permission** and nothing is sent anywhere. Detoxo simply notices while one of those apps is active in the foreground and adds up the time.

Because it works from those on-screen signals, it counts your *active* time well but can **undercount long, silent playback** — for example a video left playing untouched, which produces very little on-screen activity. So treat the number as a close, honest estimate rather than a stopwatch. It resets at the start of each new day, together with your reel count.

## How do I set or change my daily limit?

You first set a daily limit during the welcome tour by dragging a dial (the "How much do you scroll daily?" question). To change it any time, open **Settings → Daily limit**, drag the slider, and tap **Save limit** (0 means "no limit"). Your home-screen ring fills toward whatever you set. Today the limit is a self-awareness target — it colors the ring green → amber → red and tells you when you go over, but it doesn't hard-stop you; for a firm stop use **Block All** or **Conscious**.

## The floating bubble needs "Display over apps" — why?

The little counter bubble floats on top of whatever app you're in, so Android asks for the **Display over apps** permission (sometimes shown as "Draw over other apps") before it can appear. It's optional — if you skip it, counting still works everywhere; you just won't see the bubble. Blocking does not need this permission.

## What happens when I tap the counter bubble?

It depends on the **Show time on tap** option (on by default, in the bubble's appearance settings):

- **On** — a **single tap** briefly flips the bubble to show today's watch time as a running clock (e.g. `1:23:45`), then back to the count; a **double tap** opens Detoxo.
- **Off** — a **single tap** opens Detoxo.

Either way, you can **drag** the bubble to any edge and it stays where you put it.

## Will Detoxo drain my battery?

No, the impact is small. Detoxo is built to be light: it only reacts briefly when a screen changes, limits how often it checks each app, and caps how much work it does per check. There's no constant polling and nothing running in the cloud.

You will see a permanent, silent notification ("Detoxo is active") in your tray. That notification is required by Android to keep the blocker alive in the background — it's a status marker, not an alert, and it makes no sound.

## I tapped "Don't ask again" on notifications — how do I turn them back on?

Once you permanently dismiss the notification pop-up, Android won't show it again. Open **Settings → Permissions** (or the setup funnel) and the Notifications card's button now reads **Open settings** — tap it to jump straight to Detoxo's system settings and switch notifications on.

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

## How do I get help, report a bug, or suggest a feature?

Open the menu (top-right) and tap **Help & support**. You'll find: **Report an issue** (explains and turns on the feedback button, or lets you file a bug with a screenshot right away), a searchable **FAQ**, **Feature tutorials** (replay the dashboard walkthrough or a quick tour of the feedback button), and **Share an idea** (a simple box that opens your email pre-filled to us) — all routing to **errorxperts@gmail.com**. Under **Legal**, you can also open the **Privacy Policy** and **Terms & Conditions** right inside the app.

## How do I update Detoxo?

Detoxo checks the Play Store for a newer version when you open the app; if one is available it shows an **Update available** card with **Update now** (opens the Play Store) or **Later**, and you can **Skip this version** to stop being reminded about that one. To check on demand, open **Settings** and tap the **app-version card** at the bottom — if an update is ready it shows a compact **Update** button there, and if you're already current it just says so. Once in a while an update is **required** (an important fix); that card can't be dismissed until you update. Update checks run on Android only; on iPhone the app is a preview and doesn't check.

---

**Related (for the technically curious):**
[../code_docs/03-detection-engine.md](../code_docs/03-detection-engine.md) ·
[../code_docs/05-plans-pause-conscious.md](../code_docs/05-plans-pause-conscious.md) ·
[../code_docs/17-content-counter.md](../code_docs/17-content-counter.md) ·
[../code_docs/15-ios-cross-platform.md](../code_docs/15-ios-cross-platform.md)
