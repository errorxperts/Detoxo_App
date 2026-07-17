# Feature Walkthroughs

Step-by-step how-to for everything Detoxo does — in plain language, using the same
button and screen names you see in the app. Detoxo is Android-only, and
everything here runs **on your device** (this build doesn't send your activity to
a server).

If you just want the big picture first, read [Product Overview](01-product-overview.md).
For the "why does it need that?" behind each permission, see
[Permissions Explained](03-permissions-explained.md).

---

## 1. First run: the welcome tour

The first time you open Detoxo you'll see a short intro that explains what
the app does — spotting Reels, Shorts and infinite feeds, choosing which apps to
block, taking a mindful **Pause**, and building the habit.

1. Swipe through the pages, or tap **Next**.
2. Tap **Skip** (top-right) any time to jump to the end.
3. On the last page, tap **Get started**.

One page asks a single quick question — **"How much do you scroll daily?"** — with
a **drag dial**: spin it around to set your daily social-media time, and the
number animates in the centre. Your choice sets a **daily limit** that your
home-screen ring fills toward (you can change it any time in **Settings → Daily
limit**; if you skip the question, Detoxo uses a sensible default). Nothing else
is turned on or asked for during the tour. When you finish, Detoxo takes you
straight to permission setup (next section).

> You can replay this tour later from **Help & support → Feature tutorials →
> Dashboard tour**.

---

## 2. Granting permissions ("Set up protection")

For Detoxo to detect reels and pull you out of them, it needs a couple of Android
permissions. The **Set up protection** screen lists them in two groups —
**Required to block** and **Recommended** — with a short "why" under each, and a
progress bar showing how many required ones are granted.

**The two required permissions:**

| Permission (app label) | What it lets Detoxo do |
|---|---|
| **Accessibility** | Detect and block reels & shorts, and read the browser address bar for the website blocker. |
| **Display over apps** | Show the block / PIN screen on top of other apps, and float the reel-counter bubble. |

**How to grant one:**

1. Tap **Grant** next to a permission.
2. Detoxo opens the matching Android system screen (for example, the
   Accessibility list). Turn Detoxo on there and confirm.
3. Press back to return to Detoxo — the screen refreshes automatically and ticks
   off what you just granted.

The bottom button stays disabled and reads **Grant required permissions** until
both required ones are on; then it becomes **Continue** and takes you home.

**Recommended (optional) permissions** — worth enabling, but not required:

| Permission | What it adds |
|---|---|
| **Notifications** | A heads-up if protection ever stops. |
| **Usage access** | Powers app-usage limits. |
| **Unrestricted battery** | Keeps the blocker alive in the background so your phone doesn't put it to sleep. |
| **Uninstall protection** | Optional device-admin lock that makes Detoxo harder to remove on impulse. |

You can skip the optional ones now and turn them on later from
**Settings → Permissions**.

> Detoxo never trusts a "maybe" — after you return from a system settings screen
> it re-checks the real state, so the list always reflects what's actually on.

---

## 3. Choosing a blocking mode (how strict blocking is)

Your **Blocking Mode** decides what happens when Detoxo spots a reel. You pick it
from the big **Command Center** card on the home screen. Below the main dial the
modes appear as a **horizontal, swipeable row of pills** — **Block All**, **One
Reel**, **Unblock**, **Conscious**, and **Pause** (swipe sideways to reach all
five). The mode you're on is the highlighted pill, and while a **One Reel** or
**Unblock** session is live its pill shows a small remaining-count badge — plus a
live countdown/ring while a timed mode is running.

The five modes fall into two groups:

- **Base modes — they stick.** **Block All** (the default) and **Conscious**. Pick
  one and it stays put until you change it yourself.
- **Temporary modes — they auto-return.** **One Reel**, **Unblock**, and **Pause**
  are one-off overrides. When their unit finishes (the reel is watched, the batch is
  used up, the timer ends) Detoxo **automatically switches back to whichever base
  mode you were on** — Block All *or* Conscious. So a quick detour never quietly
  leaves you unprotected, and never forces you back to Block All if Conscious was
  your baseline.

> **The screen-time ring.** When no timed mode is running, the big ring shows
> **today's screen time** in the social apps Detoxo watches, filling toward your
> **daily limit** (the one you set during onboarding — §6). It shifts **green →
> amber → red** as you approach the limit, and reads "*X over your Y limit*" once
> you pass it. Below the ring, a single plain line (no boxed card) shows today's
> **Blocked** count and your **Reels** watched today. (Start a **Pause** or **Conscious**
> session and the ring switches to that session's live countdown.)

| Mode | What it does |
|---|---|
| **Block All** | The strict default and a **base** mode. Every reel or short Detoxo detects gets you pulled out immediately; it stays until you change it. |
| **One Reel** | *Temporary.* Watch a single reel, then it returns to your base mode. Tap it again to watch one more. See below. |
| **Unblock** | *Temporary.* Choose how many reels to unlock (a **2–20 dial**); watch that many, then it returns to your base mode. See below. |
| **Conscious** | A **base** mode — you *earn* watch-time by staying off reels first. See below. |
| **Pause** | *Temporary.* A short, timed break where every app is allowed; then it returns to your base mode. |

### Block All

Tap **Block All**. That's it — from now on, whenever a reel or short appears,
Detoxo gently exits it (or closes / locks the app, depending on your block-mode
choice in Settings — see §9).

### One Reel — watch one, then blocked

**One Reel** lets a single reel play, then locks blocking straight back on. It's
the lightest touch: enough to satisfy a quick curiosity without opening the
floodgates.

Tap the **One Reel** card to arm a fresh allowance of one reel. You can watch that
clip; the moment you **scroll on to the next reel**, Detoxo counts it and pulls
you out — and **returns you to your base mode** (Block All or Conscious). To watch
another, tap **One Reel** again: each tap re-arms a new single-reel allowance. While
the session is live the card shows a "**N of M reels left**" line so you can see
what's remaining.

### Unblock — choose how many, then it returns to your base

**Unblock** is One Reel with a dial: instead of exactly one reel, you decide how
many to let through before your base mode snaps back.

1. Tap the **Unblock** card — a **dialog opens with a dial**.
2. Turn the dial to pick a count — **2 to 20 reels**.
3. Tap **Unlock N reels** to start.

You can now watch that many reels; each time you **scroll to the next reel** it
counts one toward your allowance, and the card shows a live "**N of M reels left**"
line. Once you've used them up, Detoxo **returns to your base mode** (Block All or
Conscious) until you tap **Unblock** and confirm a new count — every confirmation
hands you a fresh allowance.

> Like every blocking mode, **One Reel** and **Unblock** need Detoxo's
> **Accessibility** permission switched on (§2) to detect and count reels.

### Conscious — earn your watch-time

**Conscious** is for when you want to be able to watch a little, but only if
you've stayed disciplined first. It works like a time bank:

- **While you stay off reels**, your bank fills up — about **1 minute of allowance
  for every 10 minutes** you abstain, up to a maximum of **10 minutes** banked.
- **While you watch a reel**, the bank drains in real time.
- **When the bank hits zero**, Detoxo pulls you out and blocking resumes until you
  earn more.

To turn it on: tap **Conscious** on the Command Center, then confirm in the popup.
The card then shows a live ring and a status line — *Conscious — earning* while
your bank fills, *Conscious — spending* while you're watching, and
*Conscious — ready* when you have allowance saved up. Turning Conscious off (from
the same popup) drops you back to **Block All**. Each time you switch Conscious
on fresh, you start with an empty bank — you always have to earn the first minute.

> **Your bank survives a detour.** If Conscious is your base mode and you dip into a
> temporary mode (One Reel, Unblock, or Pause), the reel-time you've banked is
> **kept** — when the detour ends and Conscious returns, you pick up where you left
> off, not from zero. (Only *choosing Conscious fresh* starts an empty bank.)

### Pause — a timed break

**Pause** temporarily suspends *all* blocking so you can scroll freely for a set
number of minutes — handy when you genuinely want a breather without turning
protection off for good.

1. Tap **Pause** on the Command Center.
2. Drag the slider to choose a length — **2 to 10 minutes** (in 2-minute steps;
   4 minutes by default).
3. Confirm. The card shows a **live countdown** and a *Paused — all apps allowed*
   banner.
4. When the timer runs out, Detoxo **returns to your base mode automatically** —
   Block All or Conscious, whichever you were on before the break. You can also tap
   **Resume** to end the break early.

The countdown is enforced by the device itself, so the break ends on time even if
you close Detoxo in the meantime.

---

## 4. Building your app blocklist ("Block apps")

Open **App Blocker** from the home screen (or the menu). The **Block apps** screen
has two parts:

### Apps & feeds (the built-in catalog)

A curated list of the apps and feed surfaces Detoxo already knows how to detect —
Instagram, YouTube, TikTok, Facebook, Snapchat, browsers, and more. Only apps you
actually have installed are shown.

- Flip a row **on** to have Detoxo watch that app's reels/shorts.
- Flip it **off** to leave that app alone.
- Browsers are grouped separately, and a search box appears once the list is long.

Changes here take effect **immediately** through the detection engine — no restart
needed.

> On a fresh install, Detoxo pre-enables the popular reel apps you already have
> installed, so protection works out of the box.

### Your own apps

Below the catalog you can add any app by name and package (for example
`com.example.app`) with the **Add app** button, then toggle or delete it.

> **Good to know:** adding your *own* custom app records your intent, but
> full whole-app locking for arbitrary apps is a planned follow-up in this build.
> The catalog toggles above (and the website blocker below) are the parts that
> actively enforce today.

---

## 5. Setting up the website blocker

Reels have a habit of following you into the browser, so Detoxo can block
distracting **websites** too. Open **Web Blocker** (home screen or menu) to reach
the **Website blocker** screen.

This works by reading the address bar in your browser, so it needs the same
**Accessibility** permission as the reel blocker (which you granted in §2).

**At the top**, a small dashboard shows **Blocked today**, **Total blocked**,
**Focus saved (min)**, and your **most-blocked** site — once you've blocked
something.

**Protection toggles:**

- **Block sites for blocked apps** — automatically blocks the websites that match
  the apps you've already blocked (e.g. blocking the Instagram app also blocks
  instagram.com).
- **Block adult content (18+)** — blocks a bundled list of adult sites.

**Adding sites:**

1. **Popular time-wasting websites** — tap a chip (YouTube, Instagram, X, Reddit,
   Netflix, TikTok, and more) to block or unblock it in one tap.
2. **Your blocklist** — tap **Add** and type a domain (e.g. `youtube.com`).
   Detoxo cleans up what you type (it accepts full URLs, `www.`, subdomains) and
   warns you if it isn't a valid site or is already on the list.
3. Each row has a switch to enable/disable it, an edit button (for sites you added
   yourself), and a delete button. A search box appears once the list grows.

When you're on a blocked site, Detoxo simply presses back to take you off it.

---

## 6. App blocker & daily limit

You first set a daily limit during onboarding (the "How much do you scroll daily?"
question — §1). To change it later, open **Daily limit** from **Settings → Daily
limit** (or the menu) to adjust the cap on how much time you want per day.

1. Drag the slider to your target — **0 to 180 minutes**, in 5-minute steps.
   (0 means "no limit set.")
2. Tap **Save limit**.

Your **home-screen ring** (§3) fills toward this limit as you use social apps, so
the number you set here is what the dashboard measures you against. The **Today**
card shows how much you've used against your cap, with a progress bar, and it
resets automatically at the start of each new day.

> **Honest note:** today the Daily limit lets you *set, see, and reset* a personal
> daily target — it's a self-awareness tool. Automatic cut-off when you reach the
> cap is a planned follow-up, so the counter won't hard-stop you yet. If you want
> a firm stop, use **Block All** or **Conscious** (§3).

---

## 7. Setting a PIN, biometrics & recovery

A PIN keeps you from disabling Detoxo (or changing protected settings) on impulse
— the whole point when your future self is the one trying to sneak past.

### Turn it on

1. Go to **Settings → PIN lock** and flip it on. This opens **PIN setup**.
2. Choose a **PIN type**:
   - **Custom** — your own **4–10 digit** code (the only real secret; stored
     safely, never in plain text).
   - **Date** — today's date as `ddMMyyyy`. Convenient, but it changes daily and
     anyone who knows the trick can unlock it.
   - **Time** — the current `HHmm`. Changes every minute.
3. Choose **where the PIN applies**:
   - **App** — ask for the PIN every time Detoxo launches.
   - **Settings** — ask before disabling blocking, resetting data, or changing the
     PIN.
4. Add a **recovery email** (required for a Custom PIN, so a forgotten code is
   always recoverable), and optionally turn on **biometric unlock**.
5. Save.

### Biometric unlock

If your phone supports fingerprint or face unlock and you enabled it at setup, the
lock screen offers a biometric shortcut (and can prompt automatically). It shows
"Unlock Detoxo" and lets you in without typing.

### If you forget your PIN

On the lock screen, tap **Forgot PIN?** and follow three steps:

1. **Email** — confirm your recovery email (shown masked if already on file).
2. **Code** — enter the code sent to you and tap **Verify**.
3. **New PIN** — set a fresh PIN and confirm.

> This build uses an offline recovery stub for testing: the code is **000000**
> (the app tells you this on the recovery screen). Wiring recovery to a real email
> service is a documented follow-up.

### A note on lockouts

Too many wrong tries triggers a cooldown that gets longer the more you miss (from
30 seconds up to 24 hours after many failures). The cooldown sticks even if you
force-quit the app — so guessing isn't a shortcut.

---

## 8. The reel counter (bubble + home-screen widget)

Detoxo counts the short videos you actually watch — Reels, Shorts, and other
infinite-feed clips — so the habit becomes visible. It's **on by default** and
runs **independently of blocking**: it keeps counting even while blocking is off,
paused, or the app is one you didn't block. A video only counts once you've
watched it for **about 2 seconds**, so quick scroll-bys don't inflate the number.

Open **Reel counter** (from the menu) to see today's and all-time counts, a
per-app breakdown, and the controls below.

### Turn the pieces on/off

On the Reel counter screen there are two switches:

- **Counting** — the master on/off for counting.
- **Bubble** — whether the floating bubble may appear.

### The floating bubble

A small draggable bubble that shows your live count and pops each time you watch
another reel.

- It appears while you're on a reel and tucks away when you leave.
- **During One Reel / Unblock it becomes an unlock countdown.** While one of those
  sessions is live, the bubble swaps today's total for a teal "**N left**" badge —
  how many reels you have left to watch — ticking down as you scroll. When the
  session ends (or you switch back to **Block All** or **Conscious**), the bubble
  **automatically returns to showing today's total reel count**. This only appears
  if the counter bubble is enabled, and only while you're actually on a reel.
- **Drag** it anywhere — it snaps to the nearest side of the screen and remembers
  where you put it.
- **Tap** behavior depends on the **Show time on tap** setting (on by default):
  - **On** — a **single tap** briefly flips the bubble to today's **watch time**
    shown as a running clock (`45s`, `3:05`, or `1:23:45`), then back to the
    count; a **double tap** opens Detoxo.
  - **Off** — a **single tap** opens Detoxo (the classic behavior).
- The bubble needs the **Display over apps** permission (from §2); without it,
  counting still works, only the bubble is hidden.

### The home-screen widget

A 2×2 widget for your home screen showing today's count, a "reels today" caption,
and your all-time total.

1. On the Reel counter appearance screen (**Home widget**), tap
   **Add to home screen**.
2. Confirm the placement your launcher offers.

The widget updates itself as you scroll — you don't need to open Detoxo to keep it
current.

### Make it yours (appearance)

Both surfaces are customizable:

- **Bubble style** — pick a look (**Glass orb**, **Usage ring**, **Emoji mood**,
  **Minimal pill**), and adjust size, text size, spacing, transparency, whether it
  shows a caption, and **Show time on tap** (tap the bubble to peek at today's
  watch time). A live preview and a **Preview count** slider let you see how it
  looks as the number climbs.
- **Home widget** — pick a background, light/dark/system **theme**, a **density**,
  which lines to show (today / caption / all-time), and whether the color shifts as
  your count grows.

Changes preview instantly and apply to the live bubble and pinned widget as you
edit.

---

## 9. Settings

Open **Settings** from the top bar or menu. It's grouped into:

**Protection**

- **Daily limit** — jumps to the daily-cap screen (§6).
- **When a reel is detected** — choose what blocking actually does:
  - **Press back** — gently exits the reel (recommended).
  - **Close the app** — force-closes the offending app.
  - **Lock app** — hides the app behind your PIN, like an app locker (requires a
    PIN; Detoxo sends you to PIN setup if you pick this without one).
- **Blocking active** — the master switch for all detection. Turning it *off* asks
  for your PIN (when the Settings scope is protected).
- **Vibrate on block** — a small buzz each time a reel is blocked.

**Security**

- **PIN lock** and **PIN settings** (§7).
- **Permissions** — a quick status summary that opens the full grant list (§2).

**General**

- **Appearance** — choose a **Theme** (System / Light / Dark) and a **Background**
  (Aurora, Sunset, Ocean, Prism). Both preview live behind the picker.
- **Feedback button** — show a quick feedback button in every top bar.

> Replaying the walkthrough now lives in **Help & support → Feature tutorials**
> (see §11), not in Settings.

**Reset**

- **Reset app data** — wipes your settings, blocklists, limits and PIN and
  restarts onboarding. It's protected by your PIN and asks for confirmation
  because it can't be undone.

---

## 10. Sending feedback

Found a bug or have an idea? Tap the **feedback** button in the top bar (enable it
via **Settings → Feedback button** if you don't see it).

1. Detoxo captures a **screenshot** of the current screen, which you can annotate.
2. Pick a category — **Bug**, **Suggestion**, or **Other**.
3. For suggestions and general feedback, optionally give a star **rating** (bug
   reports skip the rating).
4. Type your message and tap **Send feedback**.

Detoxo opens your device's email app with everything pre-filled — addressed to
**errorxperts@gmail.com**, with the screenshot attached and some app/device details
added to help us reproduce the issue. You just hit send. If no email app is set
up, Detoxo shows the support address so you can reach out manually.

---

## 11. Help & support

Open the menu (top-right) and tap **Help & support** to reach a small hub,
grouped into **Get help**, **Learn & share**, and **Legal**:

- **Report an issue** — opens a short dialog that explains how the feedback
  button works and lets you switch it on (so it appears in every top bar). Tap
  **Report a bug now** to capture the current screen right away, draw on it,
  pick **Bug** or **Suggestion**, and send it to us.
- **FAQ** — a searchable list of common questions grouped by topic (setup,
  blocking & plans, the reel counter, privacy, and more). Type in the search box
  to filter; tap a question to expand its answer.
- **Feature tutorials** — replay the guided tours:
  - **Dashboard tour** — the same welcome walkthrough of the home screen
    (this is where it lives now, having moved out of Settings).
  - **Feedback button** — a quick, one-step highlight that turns the top-bar
    feedback button on (if it's off) and points out where it is and what it does.
- **Share an idea** — a simple box to tell us what would make Detoxo better.
  Type your idea and tap **Send idea**; Detoxo opens your email app pre-filled
  and addressed to **errorxperts@gmail.com** — you just hit send.
- **Privacy Policy** and **Terms & Conditions** — open our Privacy Policy and
  Terms right inside the app, so you can read them without leaving Detoxo.

The first four route to the same support inbox as the feedback button (§10),
so use whichever is handiest.

---

## 12. Keeping the app up to date

Detoxo checks for a newer version on the Play Store when you open the app, and if
one is available it shows a tidy **Update available** card: the new version number,
what's new (when the store provides it), and two choices — **Update now** (opens
the Play Store listing) or **Later**. You can also tap **Skip this version** to stop
being reminded about that particular update.

You can check any time yourself: open **Settings** and tap the **app-version card**
at the bottom (the one showing "Detoxo v…"). If a newer version is available it
shows a compact **Update** button right there; if you're already on the newest
version, Detoxo just tells you you're up to date.

Occasionally an update is **required** (for example, an important fix). In that case
the card can't be dismissed — the only option is **Update now** — so everyone stays
on a safe, working version. This only happens on Android; on iPhone the app is a
preview and doesn't check for updates.

---

## Related

- Engineering deep-dives (for the curious): [../code_docs/05-plans-pause-conscious.md](../code_docs/05-plans-pause-conscious.md),
  [../code_docs/06-app-and-web-blocker.md](../code_docs/06-app-and-web-blocker.md),
  [../code_docs/07-daily-limit-scheduler.md](../code_docs/07-daily-limit-scheduler.md),
  [../code_docs/08-pin-lock-recovery.md](../code_docs/08-pin-lock-recovery.md),
  [../code_docs/13-onboarding-permissions.md](../code_docs/13-onboarding-permissions.md),
  [../code_docs/17-content-counter.md](../code_docs/17-content-counter.md),
  [../code_docs/20-help-support.md](../code_docs/20-help-support.md).
- Other user guides: [Product Overview](01-product-overview.md) ·
  [Permissions Explained](03-permissions-explained.md) · [FAQs](04-faqs.md).
