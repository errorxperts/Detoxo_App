# Feature Walkthroughs

Step-by-step how-to for everything Detoxo does — in plain language, using the same
button and screen names you see in the app. Detoxo is Android-only (on any other
device it shows one screen, *Detoxo works on Android only*), and everything here runs
**on your device** (this build doesn't send your activity to a server).

If you just want the big picture first, read [Product Overview](01-product-overview.md).
For the "why does it need that?" behind each permission, see
[Permissions Explained](03-permissions-explained.md).

**Getting around.** Detoxo opens on two tabs, in the glass bar at the bottom:
**Today** (your blocking mode, the screen-time ring and your blockers) and
**Insights** (your numbers for the day, §15). The **Menu** button at the top right
opens the sidebar: **Daily limit**, **Appearance**, **PIN lock**, **Settings** and
**Help & support**.

---

## 1. First run: the setup conversation

The first time you open Detoxo you'll walk through five short steps. It's a
conversation, not a slideshow — most steps ask you something, and the answers
decide what Detoxo sets up for you.

1. **Take your time back** — the Detoxo logo and one line: Detoxo spots reels the
   moment they play and pulls you back out, right inside the apps you already use.
   It blocks the reels, not the app.
2. **A few quick things** — your first name (optional), roughly how long you
   spend on short-form video a day, and what matters most to you right now
   (focus, sleep, being present, how scrolling makes you feel, or something
   else).
3. **The maths** — at the rate you just gave, how many days of your next five
   years that adds up to. It's arithmetic on your own answer, not a judgement.
   Tap **1 year**, **5 years** or **10 years** to see the horizon change.
4. **What should Detoxo guard?** — pick the feeds to protect from the apps you
   actually have installed. Instagram's Feed, Reels and Stories collapse under
   one tile, so you can be as broad or as picky as you like. You need to pick at
   least one.
5. **Here's the deal** — your first rule, in your phone's own time format (for
   example *Every day from 10 PM to 7 AM*), plus a **drag dial** for your daily
   short-form time, from 15 minutes to 5 hours. Spin it to set the **daily limit**
   the Today ring fills toward (change it any time in **Settings → Daily limit**).

Tap **Next** to move on (**Get started** on the last step), **Back** (top-left) to
change an answer, or **Skip** (top-right) on the first three steps to jump straight
to picking your feeds. If you skip the questions, Detoxo sets up the *30m of feed a
day* budget it shows you on the last step — you always get the rule you were
promised.

**You can stop at any point.** Every answer is saved the moment you give it, and
the step you're on is remembered — close the app, restart your phone, whatever,
and you'll come back exactly where you left off rather than starting over.

When you finish, Detoxo takes you to permission setup (next section). **The
moment you grant the required permissions, Detoxo sets up your first rule for
you**, based on what you said matters most:

| You picked | Detoxo sets up |
|---|---|
| Sleep | The feeds you picked, blocked every day from 10 PM to 7 AM |
| Focus | The feeds you picked, blocked on weekdays from 9 AM to 5 PM |
| Being present · How I feel · Something else | 30m of feed a day, then blocked until tomorrow |

Times follow your phone's 12- or 24-hour setting. It's an ordinary rule like any
other — open **Blocker rules** (at the bottom of the Today tab) to change the hours,
the apps, or delete it entirely.

> Already using Detoxo before this update? Nothing changes for you — you won't be
> asked to go through setup again, and no rule is created behind your back.

> You can replay the in-app feature tour later from **Help & support → Feature
> tutorials → Today tour**.

> On a new install, the block screen's *opened N times today* line starts off. Turn
> it on any time under **Appearance → Block screen → Times opened today**.

---

## 2. Granting permissions ("Set up protection")

For Detoxo to detect reels and pull you out of them, it needs a couple of Android
permissions. The **Set up protection** screen lists them in two groups —
**Required to block** and **Recommended** — with a short "why" under each; the
**Required to block** heading counts how many are on (*1 of 2 on*).

**The two required permissions:**

| Permission (app label) | What it lets Detoxo do |
|---|---|
| **Accessibility** | Detect and block reels & shorts, and read the browser address bar for the Web Blocker. |
| **Display over other apps** | Show the block / PIN screen on top of other apps, and float the reel-counter bubble. |

**How to grant one:**

1. Tap **Grant** next to a permission.
2. Detoxo opens the matching Android system screen (for example, the
   Accessibility list). Turn Detoxo on there and confirm.
3. Press back to return to Detoxo — the screen refreshes automatically and the
   permission's status changes from **Needs access** to **On**.

The bottom button stays disabled and reads **Grant required permissions** until
both required ones are on; then it becomes **Continue** and takes you home.

> **A brief "Checking…" is normal.** Right after launch, a card can show a
> neutral **"Checking…"** for a moment while Detoxo reads the real status from
> Android. That's not a denial
> and not "protection off" — it settles on its own, usually within a second, and
> never un-grants anything you've already set up.

**Recommended (optional) permissions** — worth enabling, but not required:

| Permission | What it adds |
|---|---|
| **Notifications** | A heads-up if protection ever stops. |
| **Usage access** | Powers app-usage limits and the **Insights** tab. |
| **Unrestricted battery** | Keeps the blocker alive in the background so your phone doesn't put it to sleep. Android asks once whether Detoxo may run in the background — choose **Allow**. |
| **Uninstall protection** | Optional device-admin lock that makes Detoxo harder to remove on impulse. |
| **Notification access** | Silences notifications from apps you've locked (§16). |

You can skip the optional ones now and turn them on later from
**Settings → Permissions**.

> Detoxo never trusts a "maybe" — after you return from a system settings screen
> it re-checks the real state, so the list always reflects what's actually on.

---

## 3. Choosing a blocking mode (how strict blocking is)

Your **Blocking Mode** decides what happens when Detoxo spots a reel. You pick it
on the **Today** tab, from the **mode card** under the ring: **Block All**,
**Conscious**, **Pause** and **One Reel**, side by side. The mode you're on is lit, and
a line under the four says what it is doing right now, for example *All reels
blocked* or *Blocking resumes in 09:42*. An **Unblock** session lights **Pause**. If
blocking is switched off in Settings, the line says *Blocking is off* instead.

The modes fall into two groups:

- **Base modes — they stick.** **Block All** (the default) and **Conscious**. Pick
  one and it stays put until you change it yourself.
- **Temporary modes — they auto-return.** **One Reel**, **Unblock**, and **Pause**
  are one-off overrides. When their unit finishes (the reel is watched, the batch is
  used up, the timer ends) Detoxo **automatically switches back to whichever base
  mode you were on** — Block All *or* Conscious. So a quick detour never quietly
  leaves you unprotected, and never forces you back to Block All if Conscious was
  your baseline.

> **The screen-time ring.** The big ring at the top of Today shows the **time you
> have left** today in the social apps Detoxo watches before you reach your **daily
> limit** (the one you set during onboarding, §6), with how much you've used
> (*45m of 3h used*). Past the limit it reads **0m** and "*45m over your 3h limit*";
> with no limit set it shows today's total. Below the ring, one plain line shows the
> **reels** you've watched today and your **day streak**, the number of days in a row
> you've stayed under your daily limit. During a **Pause** or an **Unblock** the ring
> shows that session instead, the time or the reels you have left; tap the lit mode
> again to end it straight away.

| Mode | What it does |
|---|---|
| **Block All** | The strict default and a **base** mode. Every reel or short Detoxo detects gets you pulled out immediately; it stays until you change it. |
| **One Reel** | *Temporary.* Watch a single reel, then it returns to your base mode. Tap it again to watch one more. See below. |
| **Unblock** | *Temporary.* Tap **Unblock** in the mode card and choose how many reels to let through (**1–20**); watch that many, then it returns to your base mode. See below. |
| **Conscious** | A **base** mode — you *earn* watch-time by staying off reels first. See below. |
| **Pause** | *Temporary.* A short, timed break from reel and website blocking; then it returns to your base mode. (Apps you've fully locked stay locked.) |

### Block All

Tap **Block All**. That's it — from now on, whenever a reel or short appears,
Detoxo exits it (or closes / locks the app, depending on your block-mode choice
in Settings — see §9). Pick the **Block screen** mode there and it also shows its
**block screen**: a calm full-screen card with a short motivational quote and a
line that names the app ("Instagram can wait. Your peace can't."), says why it's blocked
("Block All is on") and shows today's reel count (and, if you turn it on, how many times
you've opened that app today), with three ways out — the **Home** button (⌂), **Open
Detoxo**, or **Back to Instagram**, which lands you
on Instagram's home feed (Detoxo taps its Home tab for you; if you'd ended up deep in a
chat, Instagram reopens on the feed). That last one waits five seconds before it unlocks ("Back to
Instagram · 5") so the block registers before the reflex tap; the other two are
instant. Swiping back from the screen's edges is ignored while the card is up. The
card stays put wherever the exit dropped you — the app itself, your home screen, or
the app you came from (there it simply reads **Dismiss**) — and disappears on its
own when you move on to a different app, turn the screen off, start a Pause, or
switch protection off. In **Conscious** the card also tells you your time bank is
empty; in **One Reel** / **Unblock** it says you've watched your reel(s). The card
follows Detoxo's own theme, light or dark, in one calm layout: the quote sits in a
frosted panel under an icon for why you were blocked, and its colour is the one your
Today screen shows right now. Nothing on it moves after it appears. You can drop the
wait or the extra lines —
or switch it off for app and website blocks — under **Appearance → Block screen**
(§8, §9). Whatever mode you
pick, the card always appears once your **daily limit** is used up (§6), when a
**schedule** you set kicks in, or when your **Conscious** bank runs dry — those are
commitments you made in advance, so Detoxo always shows you the wall for them.

### One Reel — watch one, then blocked

**One Reel** lets a single reel play, then locks blocking straight back on. It's
the lightest touch: enough to satisfy a quick curiosity without opening the
floodgates.

Tap **One Reel** in the mode card. A sheet asks **Watch one reel?** Wait a few
seconds ("Take a breath…"), then slide to unblock, or tap **Keep it blocked** to
back out. Once you slide, Detoxo says **One reel unblocked** and you can watch that
clip; the moment you **scroll on to the next reel**, Detoxo counts it and pulls
you out — and **returns you to your base mode** (Block All or Conscious). To watch
another, tap **One Reel** and slide again: each time re-arms a new single-reel
allowance. Until you've watched it, the mode card reads *One reel left*; tap the
lit **One Reel** to block again straight away.

### Unblock — choose how many, then it returns to your base

**Unblock** is One Reel with a count: instead of exactly one reel, you decide how
many to let through before your base mode snaps back.

1. Tap **Unblock** in the mode card. The **Session blocker** sheet opens
   **By reel count**.
2. Pick a count — **1 to 20 reels**, 10 to start — by dragging around the ring or
   with a quick pick (5, 10, 15, 20). The line underneath says
   when blocking resumes.
3. Tap **Start 10-reel session** (the button follows your count). It turns green
   and reads **Session started**, then the sheet closes.

You can now watch that many reels; each time you **scroll to the next reel** it
counts one toward your allowance. The Today ring counts down the reels you have
left (*3 of 5 reels*), and the mode card reads *3 reels left, then blocked again*.
Tap the lit **Unblock** again to end it early. Once you've
used them up, Detoxo **returns to your base mode** (Block All or
Conscious) until you tap **Unblock** and start a new count — every start hands you a fresh
allowance.

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

To turn it on: tap **Conscious** in the mode card. The sheet explains the deal —
*Earn 1 minute of reels for every 10 minutes away, up to 10 minutes banked* — then
tap **Turn on Conscious**. While it's on, the same sheet shows your bank (*04:12*,
*banked · cap 10m*) and one line on what it's doing; **Turn off Conscious** sits
under it. The line under the mode card follows your bank too: *Earning 1
min for every 10 min away* while it fills, *Spending banked time, 04:12 left* while
you're watching, and *04:12 banked to spend* when you have time saved. To turn it
off, tap **Conscious** again and choose **Turn off Conscious**, or tap **Block All**;
either way you're back on **Block All**. Each time you switch Conscious
on fresh, you start with an empty bank — you always have to earn the first minute.

> **Your bank survives a detour.** If Conscious is your base mode and you dip into a
> temporary mode (One Reel, Unblock, or Pause), the reel-time you've banked is
> **kept** — when the detour ends and Conscious returns, you pick up where you left
> off, not from zero. (Only *choosing Conscious fresh* starts an empty bank.)

> **…but not overnight.** The bank resets at the start of each day, so
> yesterday's discipline doesn't buy this morning's scroll — every day you earn
> your watch-time fresh.

### Pause — a timed break

**Pause** temporarily suspends reel and website blocking so you can scroll
freely for a set number of minutes — handy when you genuinely want a breather
without turning protection off for good.

1. Tap **Pause** in the mode card. The **Session blocker** sheet opens
   **By time** (to unblock a number of reels instead, see Unblock above).
2. Drag the dial to choose a length — **1 to 10 minutes**, 5 to start — or tap a
   quick pick (1, 3, 5, 10). The line underneath shows the time blocking resumes,
   in your phone's 12- or 24-hour format.
3. Tap **Start 5-min session** (the button follows your choice). It reads
   **Session started**, the sheet closes, and the Today ring counts down the time
   left.
4. When the timer runs out, Detoxo **returns to your base mode automatically** —
   Block All or Conscious, whichever you were on before the break. You can also tap
   the lit **Pause** again to end the break early.

> **App locks hold through a Pause.** Apps you've fully locked on the **App
> Blocker** screen stay locked during the break — a Pause is for reels and
> websites, not a back door into an app you deliberately locked. To open a
> locked app, flip its switch off on the App Blocker screen.

The countdown is enforced by the device itself, so the break ends on time even if
you close Detoxo in the meantime.

---

## 4. Building your app blocklist ("App Blocker")

Open **App Blocker** from its tile on the Today tab. Under the **Blockers** heading
(which counts how many of the two are on, *1 of 2 on*), the App Blocker and Web
Blocker tiles show whether each is **On**, **Paused** or **Not set up**, with the
first few apps or sites you block (and "+N" for the rest). Tap a tile to open it;
the tiles refresh when you come back.

The **App Blocker** screen has two parts:

### Apps & feeds (the built-in catalog)

A curated list of the apps and feed surfaces Detoxo already knows how to detect —
Instagram, YouTube, TikTok, Facebook, Snapchat, browsers, and more. Only apps you
actually have installed are shown.

- Flip a row **on** to have Detoxo watch that app's reels/shorts.
- Flip it **off** to leave that app alone. Switching a feed off shows "*Feed*
  unblocked" with **Undo**.
- An app with several feeds (Instagram's Feed, Reels and Stories) is one row: tap it
  to choose which feeds to block (*2 of 3 blocked*).
- Browsers are grouped separately, and a search box appears once the list is long.

Changes here take effect **immediately** through the detection engine — no restart
needed.

> On a fresh install, Detoxo pre-enables the popular reel apps you already have
> installed, so protection works out of the box.

### Your own apps ("Custom apps")

You can add any app with the **Add app** button at the bottom of the screen: it opens
a picker showing every app on your phone — icon, name and all — so you just
search, tap one or several, and confirm. Apps you've already added are marked
and can't be picked twice. Can't find one (some work-profile apps hide from the
list)? Use **"Can't find it? Add manually"** to enter its name and package id
(for example `com.example.app`) — Detoxo checks the id's shape and tells you if
it can't be right, and just installed the app? Tap the **refresh** button next
to the search box. Your added apps appear at the top under **Custom apps** (the
section only appears once you've added something), with their real icons and names.
Swipe a row left (or tap it) for **Unblock** and **Remove**; an unblocked row reads
"Not blocked" and offers **Block** there instead. Tap the timer on a row to allow that
app for a while; the row then reads "Allowed until …" with a **Block now** button to end
it early.

> **Good to know:** apps you add here are **really blocked**. Open one and
> Detoxo bounces you straight back to your home screen with a short
> "*App* is blocked by Detoxo" message (and a little vibration, if you have
> block vibration on). It works even if you were already inside the app when
> you added it, and each bounce counts toward your "Blocked today" number.
> Swipe the row (or tap it) and choose **Unblock** or **Remove** whenever you want the app back.
> Either way, a short message offers **Undo** for a few seconds in case you
> change your mind.
> Detoxo will never block your home screen, itself, or a protected app (§13).

---

## 5. Setting up the Web Blocker

Reels have a habit of following you into the browser, so Detoxo can block
distracting **websites** too. Tap the **Web Blocker** tile on the Today tab to open
it.

This works by reading the address bar in your browser, so it needs the same
**Accessibility** permission as the reel blocker (which you granted in §2).

**At the top**, a small panel shows **Blocked today**, **Total blocked**,
**Focus saved** (like *1h 20m*), and your **Most blocked** site — once you've
blocked something.

**Protection** — the row under the Popular sites chips opens its own screen with
two switches that each block a whole category at once; the row shows how many are
on (*1 of 2 on*):

- **Block websites of blocked apps** — automatically blocks the websites that match
  the apps you've already blocked (e.g. blocking the Instagram app also blocks
  instagram.com, and blocking WhatsApp also blocks web.whatsapp.com). Detoxo's
  built-in app catalog knows the web home of every app it lists.
- **Block adult content (18+)** — blocks every page of 200+ known adult sites
  plus every `.xxx`, `.porn`, `.sex` or `.adult` address, in any supported
  browser. These blocks count toward your stats but are never named: no adult
  site name ever appears in the toast or the "Most blocked" line.

Turning either protection off asks you to wait a few seconds and slide to confirm.
Turning it back on is instant.

**Which browsers are supported?** Detoxo blocks websites by reading the address
bar, and it knows how to do that in about thirty browsers — Chrome, Firefox,
Samsung Internet, Edge, Brave, Opera, DuckDuckGo, Vivaldi and the rest. If you
have one it doesn't recognise, the Web Blocker screen says so by name at the
bottom (*Not covered: …*; tap the line for why), because in that browser your
blocklist and the 18+ filter do nothing. Detoxo would rather tell you than look like
it's protecting you. If that happens, you can switch browsers or add the browser
itself to the **App Blocker**.

**Adding sites:**

1. **Popular sites** — two rows of chips (YouTube, Instagram, X, Reddit,
   Netflix, TikTok, and more) that scroll sideways together; tap one to block or
   unblock it, or scroll to the end and tap **Add website** for your own.
2. **Your blocklist** — tap **Add website** and type a domain (e.g.
   `youtube.com`). Detoxo cleans up what you type (it accepts full URLs,
   `www.`, subdomains) and warns you if it isn't a valid site or is already on
   the list.
3. Each row has a switch to enable/disable it. Swipe the row left — or just tap
   it — to reveal its actions: **Allow**, **Edit** (for sites you added
   yourself) and **Delete**. A search box appears once the list grows.
   Switching a site off, deleting it, or tapping a lit popular site shows a short
   message with **Undo**.

**Need a blocked site for a few minutes?** Tap the row, choose **Allow**, pick 5,
15, 30 or 60 minutes, wait a moment and slide to confirm. The row shows "Allowed
until …", the site opens normally until then, and blocking switches itself back on
when the time is up — even if you never reopen Detoxo. To end it early, tap the row
and choose **Resume**.

When you're on a blocked site, Detoxo simply presses back to take you off it.

---

## 6. Daily limit

You first set a daily limit during setup (the drag dial on the "Here's the deal"
step — §1). To change it later, open **Daily limit** from **Settings → Daily
limit** (or the menu) to adjust the cap on how much time you want per day.

1. Drag the slider to your target — **0 to 8 hours**, in 15-minute steps.
   (0 means no limit.)
2. Tap **Save limit**.

Your **screen-time ring** on the Today tab (§3) fills toward this limit as you watch
reels, so the number you set here is what the ring measures you against. The
**Today** section shows today's reel time (say *45m*) and *45m of 3h used*, with a
progress bar; it resets at the start of each new day.

**It's a real stop.** When today's reel time reaches the limit, Detoxo blocks
every reel feed it knows — Reels, Shorts and the rest — until midnight, with the
block screen saying *"Your daily limit is used up."* That card shows whatever
block mode you chose and even if you switched the block screen off under
Appearance. The rest of each app keeps working; only the feeds are closed. A **Pause** lifts it like any other block
(§3). The limit is measured by the **reel counter** (§8), so if you switch the
counter off, the Daily limit screen shows *Reel counter is off* — tap it to open
Appearance. Without *Display over other apps* it says so too; feeds still close at
the limit, and a tap asks for the permission. You'll also see the limit pinned at the
top of **Blocker rules** (§14).

---

## 7. Setting a PIN, biometrics & recovery

A PIN keeps you from disabling Detoxo (or changing protected settings) on impulse
— the whole point when your future self is the one trying to sneak past.

### Turn it on

1. Go to **Settings → PIN lock** and flip it on. This opens the **PIN lock** screen.
2. Choose a **PIN type**:
   - **Custom PIN** — your own **4–10 digit** code (the only real secret; stored
     safely, never in plain text).
   - **Today's date** — the date as `ddMMyyyy`. Convenient, but it changes daily
     and anyone who knows the trick can unlock it.
   - **Current time** — the current `HHmm`. Changes every minute.
3. Choose what the PIN protects, under **Protect**:
   - **Opening Detoxo** — ask for the PIN every time Detoxo launches.
   - **Changing protected settings** — ask before disabling blocking, resetting
     data, or changing the PIN.
4. With **Opening Detoxo** on, tune **Auto-lock**:
   - **Re-lock after leaving Detoxo** — pick when the lock re-arms after you
     switch away: immediately, after 15 or 30 seconds, after 1 minute (the
     default) or 5 minutes, when the screen turns off, or never (only on
     relaunch). Detoxo always locks again after a phone restart.
   - **Hide screen in Recents** — blanks Detoxo's card in the app switcher so
     nobody glimpses your settings or counts. This also blocks screenshots of
     the app while it's on.
5. Optionally turn on **Unlock with fingerprint or device credential**.
6. Tap **Save PIN**. If something is missing, the screen says so right under that
   section (for example *Use at least 4 digits*).

   Under it, the screen says plainly: *Detoxo can't recover a forgotten PIN.
   Reinstalling clears it with all settings.* Pick something you'll remember.

Turning the PIN lock off (from Settings, or by choosing **None** as the PIN type)
asks for your PIN, then asks you to wait a few seconds and slide to confirm.

### Fingerprint & device-credential unlock

If your phone supports it and you enabled it at setup, the lock screen offers a
fingerprint shortcut (and can prompt automatically). The system sheet shows
"Unlock Detoxo" and also accepts your **device PIN, pattern or password** as a
fallback — so you have three ways in: Detoxo's PIN, a fingerprint or face, or
your device credential.

### If you forget your PIN

There is **no reset**, by design. Your PIN is hashed and stored on your phone
only — there's no account, no server and no support code behind it. Any code the
app could accept would be a bypass available to anyone holding your phone.

Tapping **Forgot PIN?** on the lock screen says exactly that, and names the one
real escape hatch: **uninstall Detoxo and install it again**, which clears the
PIN along with your settings, blocklists and counts. If uninstall protection is
on, turn it off first in *Settings → Security → Device admin apps*.

### A note on lockouts

Too many wrong tries triggers a cooldown that gets longer the more you miss (from
30 seconds up to 24 hours after many failures). The cooldown sticks even if you
force-quit the app — and it's tied to the phone's internal uptime clock, so
changing the date or time in Settings doesn't skip the wait either. Guessing
isn't a shortcut. The countdown shows right under the PIN dots; there is no
pop-up.

---

## 8. The reel counter (bubble + home-screen widget)

Detoxo counts the short videos you actually watch — Reels, Shorts, and other
infinite-feed clips — so the habit becomes visible. It's **on by default** and
runs **independently of blocking**: it keeps counting even while blocking is off,
paused, or the app is one you didn't block. A video only counts once you've
**stopped on it for about a second**, and the same reel never counts twice — quick
scroll-bys, half-swipes and scrolling the comments don't inflate the number.

The counter's controls live on the **Appearance** screen — open it from the menu
(or **Settings → Appearance**) to turn counting on/off, toggle the bubble, and
customize both surfaces. To see today's count, the all-time total and a per-app
breakdown, open the **Insights** tab, which also shows your whole-phone screen time
(§15).

### Turn the pieces on/off

On the **Appearance** screen, under **Reel counter**:

- **Count short videos** — the master on/off for the whole counter. With it
  off, Detoxo says so wherever a number would otherwise mislead: the
  **Insights** tab explains that counting is off, and the Today ring reads
  *Counting is off* instead of a reassuring zero (and your "days under your
  limit" streak doesn't advance on an unmeasured day).
- Below it, the **Bubble** and the **Widget** (your home-screen widget) sit side
  by side, each with a large live preview and a status underneath: **On**,
  **Off** or **Needs access**. The **Bubble** has its own on/off switch; tap
  either preview to open its editor (available once the relevant switch, and
  counting, is on).
- If the bubble is switched on but Android's **Display over other apps**
  permission is missing, its status reads **Needs access**. Tap it to open the
  setting; it changes back to **On** by itself when you come back with the
  permission granted.

### The floating bubble

A small draggable bubble that shows your live count, pops each time you watch
another reel, starts in your theme's colour and changes colour every 100 reels.

- It appears while you're on a reel and tucks away when you leave.
- **During One Reel / Unblock it becomes an unlock countdown.** While one of those
  sessions is live, the bubble swaps today's total for a teal "**N left**" badge —
  how many reels you have left to watch — ticking down as you scroll. When the
  session ends (or you switch back to **Block All** or **Conscious**), the bubble
  **automatically returns to showing today's total reel count**. This only appears
  if the counter bubble is enabled, and only while you're actually on a reel.
- **Drag** it anywhere — it snaps to the nearest side of the screen and remembers
  where you put it.
- **Tap** the bubble to flip it to today's **watch time** as a running clock
  (`00:45`, `03:05` or `1:23:45`); tap again to return to the count. The bubble
  never opens Detoxo.
- The bubble needs the **Display over other apps** permission (from §2); without it,
  counting still works, only the bubble is hidden.

### The home-screen widgets

Six widgets for your home screen. Each shows today's reels in a different way, and
each comes in **Small** (2×2), **Medium** (4×2) and **Large** (4×4):

| Widget | What it shows |
| --- | --- |
| **Count** | Today's reels at a glance, with your watch time. The tile's colour is your "tier". |
| **Next colour** | A ring that fills over each block of 100 reels; when it closes, the tile changes colour. |
| **Time limit** | Watch time left in today's limit, in twelve segments. Past the limit it shows how far over you are. |
| **Rhythm** | When today's scrolling happened, hour by hour, with your peak hour called out. |
| **Bonsai** | A little tree that loses a stage every 100 reels, from **Blooming** to **Leafless**. |
| **Bento** | Your count, watch time and next colour in calm, separate tiles. |

**The colour is your tier, in your theme.** The bubble and every widget use
Detoxo's blue for your theme. Every 100 reels the tile turns a
deeper shade of it: pale at 1–99, deepest at 400 and more ("Final colour"). With no
reels yet it's a quiet tile that says **No reels yet**. A widget set to Light or Dark
uses your theme's colour for that mode.

To add one:

1. On the **Appearance** screen, open **Home widget**.
2. Swipe through the six widgets, or tap one in the row below the big preview.
   Switch **Small / Medium / Large** to see each size, and pick a **theme**
   (System, Light or Dark).
3. Tap **Add to home screen** and confirm the placement your launcher offers.
4. A new widget lands at 2×2. To get Medium or Large, **long-press it and drag its
   edges** — it switches to the matching layout as you resize.

You can also add any of them straight from your launcher's widget list: look for
**Detoxo**, which lists all six by name. You can put several on your home screen at
once.

**Time limit** counts down the soonest reel limit that's active today — your
**Daily limit**, or a reel time limit from one of your **Blocker rules**. With none set it
honestly says **No daily limit**, and the Home widget screen offers **Set a daily
limit**.

How they stay current:

- They update on their own while you scroll, without opening Detoxo. To save
  battery they refresh **every 10 reels and at each colour change** (and whenever
  you leave Detoxo), so the number on your home screen can trail the live count by
  a few reels.
- At midnight they start the new day on their own.
- If Detoxo hasn't been able to refresh them for an hour (for example the
  Accessibility service was stopped), they keep the last numbers and say
  **Updated 9:40 PM**.
- If counting is off, or Detoxo's Accessibility service isn't on, they say **Turn
  on tracking**; tapping the widget takes you straight to the fix.
- Otherwise, tapping a widget opens **Insights**.

### Make it yours (appearance)

Both surfaces are customizable from the **Appearance** screen — each is shown as a
live preview of your current style; tap it to open the editor:

- **Bubble style** — pick one of six looks: **Mascot**, **Ring**, **Liquid**,
  **Hourglass**, **Bezel** or **Drop**, and adjust its **Size** and **Opacity**. Every look changes colour
  each time you cross another hundred reels, and shows a small pill with today's
  watch time (for example `48m` or `1h 12m`) for a few seconds when it appears and
  at each new colour. A live preview and a **Preview count** slider show how it
  looks as the number climbs.
- **Home widget** — pick one of the six widgets, preview it Small, Medium or
  Large, choose a light/dark/system **theme**, and add it to your home screen (see
  above). The theme applies to every Detoxo widget you've placed.
- **Block screen** — the full-screen card shown when something is blocked (§3).
  Its panel on the Appearance screen carries its own **on/off switch**, a live
  preview and a status: **On**, **Off · toast instead** (app and website blocks
  then fall back to a short toast) or **Needs access**. Tap the preview, even
  while it's off, to open its own page, with the same switch at the top, a big
  preview and three **Options**: **Reel count today**, **Times opened today** (it
  needs the Usage access permission, and starts off on a new install) and **Wait 5
  seconds to go back** (whether **Back to the app** waits before it unlocks). Its
  look follows the theme you picked for Detoxo itself, light or dark, so changing
  the theme above changes the card too, and its colour follows your current mode,
  as on the Today screen. **Try it on your phone** raises the real
  card over the editor so you can see exactly what a block looks like. While the
  block screen is off, its preview turns grey and says **Off**, and the options and
  **Try it** wait for you to switch it back on. Like the bubble, it needs "Display
  over other apps": without the permission its status reads **Needs access**, and
  a tap opens the setting.

Changes preview instantly and apply to the live bubble, your placed widgets and
the block screen as you edit.

---

## 9. Settings

Open **Settings** from the sidebar (the **Menu** button at the top right of Today or
Insights). It's grouped into:

**Protection**

- **Daily limit** — jumps to the daily-cap screen (§6).
- **When a reel is detected** — choose what blocking actually does:
  - **Press back** — exits the reel (recommended).
  - **Block screen** — exits the reel and shows the full-screen block screen with
    a way back (needs "Display over other apps"; Detoxo opens Android's screen if
    it's missing, and the row underneath says so until you allow it — until then
    the reel still closes and a short toast names the block). With any other mode
    the card only appears when your daily limit is used up, a schedule kicks in,
    or your Conscious bank runs dry.
  - **Close the app** — closes the app.
  - **Lock app** — hides the app behind your PIN, like an app locker (requires a
    PIN; Detoxo sends you to PIN setup if you pick this without one).
- **Blocking active** — the master switch for all detection. Turning it *off* asks
  for your PIN (when the Settings scope is protected), then asks you to wait a few
  seconds and slide to confirm.
- **Vibrate on block** — a small buzz each time a reel is blocked.
- **Allowances** — how often a day you can free one app, feed or site (§18).
- **Soft nudge** — a card that says how long you've been in a distracting app (§17).

**Privacy** — **Protected apps** (§13) and **Notification silence** (§16).

**Security**

- **PIN lock** and **PIN settings** (§7).
- **Permissions** — a quick status summary that opens the full grant list (§2).

**General**

- **Appearance** — opens the Appearance screen: choose a **Theme** — **System**
  (follows your device), **Light** or **Dark** (the default). Manage the
  **reel counter** here too
  (counting, the bubble, bubble style and the home widget) and the **block
  screen** (its on/off switch and look — §8). Everything previews live.
- **Feedback button** — show a quick feedback button in every top bar.
- The **version row** — *Detoxo v…*; tap it to check for updates (§12).

> Replaying the walkthrough now lives in **Help & support → Feature tutorials**
> (see §11), not in Settings.

**At the bottom**

- **Reset app data** — erases your settings, blocklists, limits and PIN, and setup
  starts again. It's protected by your PIN, then asks you to wait a few seconds and
  slide to confirm, because it can't be undone.

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

- **Report an issue** — opens a short sheet with a switch for the feedback
  button (so it appears in every top bar). Tap **Report a bug** to capture this
  screen, mark it up and send it to us.
- **FAQ** — a searchable list of common questions grouped by topic (setup,
  blocking & plans, the reel counter, privacy, and more). Type in the search box
  to filter; tap a question to expand its answer.
- **Feature tutorials** — replay the guided tours:
  - **Today tour** — the same welcome walkthrough of the Today tab (this is where
    it lives now, having moved out of Settings). It walks you through all four
    blocking modes — **Block All**, **Conscious**, **Pause** and **One Reel** — plus
    the **App Blocker** and **Web Blocker** tiles.
  - **Feedback button** — a quick, one-step highlight that turns the top-bar
    feedback button on (if it's off) and points out where it is and what it does.
- **Share an idea** — a simple box to tell us what would make Detoxo better.
  Type your idea and tap **Send idea**; Detoxo opens your email app pre-filled
  and addressed to **errorxperts@gmail.com** — you just hit send.
- **Privacy Policy** and **Terms & Conditions** — open our Privacy Policy and
  Terms right inside the app, so you can read them without leaving Detoxo.

**Report an issue** and **Share an idea** reach the same support inbox as the
feedback button (§10), so use whichever is handiest.

---

## 12. Keeping the app up to date

Detoxo checks for a newer version on the Play Store when you open the app, and if
one is available it shows a short **Update available** sheet: the new version
number, the release notes under **What's new** (when the store provides them), and
two choices — **Update now** (opens the Play Store listing) or **Later**. You can
also tap **Skip this version** to stop being reminded about that particular update.

You can check any time yourself: open **Settings** and tap the version row at the
bottom of **General** (*Detoxo v…*, *Tap to check for updates*). If a newer version
is available it reads *Version … is available* with an **Update** button right
there; if you're already on the newest version, a short message says so.

Occasionally an update is **required** (for example, an important fix). In that case
the sheet can't be dismissed — the only option is **Update now** — so everyone stays
on a safe, working version. Like the rest of Detoxo, update checks run on Android
only.

---

## 13. Protected apps: Detoxo steps aside for your private apps

> **Protected apps**
>
> Detoxo never reads, counts, blocks or interrupts these apps. It pauses while
> you use them.

Open **Settings → Privacy → Protected apps**. While a protected app is on
screen, Detoxo does **nothing at all** — no counting, no blocking, no bubble,
no reading what's on screen. The moment you leave it, protection resumes on its
own. You never have to toggle anything.

**Automatic, always.** Well-known sensitive apps — banks like HDFC or SBI's
YONO, UPI apps like Google Pay and PhonePe, DigiLocker, password managers,
authenticators and more — are protected automatically and **permanently**.
There is nothing to set up and nothing to get wrong: they can't be switched
off or removed, and one you install *later* is covered the moment it lands on
your phone. The screen lists them under **Auto-protected**, each with its
category (Banking, Password manager, …), so you can see exactly what's covered.

**Adding your own.** Tap the **Add app** button and pick straight from a list of the apps
on your phone — search by name, select one or several, done. Apps that are
already covered show a small label ("Auto-protected" or "Protected") so you
can't add them twice, and apps you've blocked show "Blocked" — an app can be
protected *or* blocked, never both; remove it from one list to add it to the
other. (The same rule appears in the **App Blocker**: protected apps — including
the always-on sensitive ones — can't be blocked.) If an app doesn't appear in
the list (some work-profile apps hide themselves), **"Can't find it? Add
manually"** lets you enter its name and package id (it's in the app's Play
Store URL) — Detoxo checks the id's shape and tells you if it can't be right,
so a typo never leaves a bank looking protected when it isn't. Just installed
the app? Tap the **refresh** button next to the search box. Apps you add appear
under **Your apps** once you add the first one, with their real icons, and those
you can delete any time.

**One honest guard-rail:** protection beats blocking — so protecting, say,
Instagram would quietly switch its blocking off. If any app you're protecting
is one Detoxo can block, Detoxo asks for your Settings PIN once for the whole
batch (when you have one), exactly like turning blocking off.

Your protected list never leaves your phone, and Detoxo's diagnostics never
mention these apps — not even that you opened one.

---

## 14. Blocker rules: block on a schedule, or cap your day

The **Blocker rules** row sits at the bottom of the Today tab, under the App Blocker
and Web Blocker tiles. It shows how many rules are on and what happens next, in your
phone's 12- or 24-hour format (*Bedtime on until 7 AM*, *Next: Bedtime at 11 PM*,
*Next: Wind down at 10 PM on Fri*). Tap it to open **Blocker rules**. If you have no
rules yet you'll see **Start from a preset**: one tap on *Work hours* (Weekdays
9 AM–5 PM · reels and social), *Sleep* (Every day 10 PM–7 AM · reels, social and
streaming), *Dinner* (Every day 7 PM–8 PM · reels) or *Reel budget* (30m of reels a
day, then blocked until midnight) opens a rule already filled in, so you can adjust
it and save. Nothing is saved until you do.

To build one from scratch, tap **New rule** and pick one of three kinds:

- **Schedule** — block during set hours on the days you choose. Pick the days
  (weekdays are pre-selected), a start and an end time. An end time earlier than
  the start means "overnight": *Fri 10 PM → 6 AM* blocks Friday night **and**
  the early hours of Saturday, because that whole night counts as Friday.
- **Time limit** — a daily budget, from 5 minutes to 4 hours. Once it's
  spent, the apps are blocked until midnight.
- **Open limit** — a number of launches per day (1 to 20). After that many
  opens, the app is blocked until midnight.

Then choose what the rule covers under **Block**: add specific **apps** from the
picker (your protected apps are marked and can't be picked), and — for schedules —
**reel feeds** (Instagram Reels, YouTube Shorts…) and **websites** (popular-site
chips or any address you type). Below those, swipe the two rows of **category**
chips (Short-form video, Social, Games…); **All distracting** picks every
distracting category in one tap, and tapping it again clears them. A schedule can
mix all four; time and open limits work on apps and categories, since Android
only counts time per app. **Strict** and **Lock this rule** sit under
**Commitment**, just above Save.

When a rule is blocking, the app bounces you home (or backs out of the site,
or closes the feed) and the block screen tells you when you get it back:
**"Blocked by a schedule · Unlocks at 5:30 PM"**, or **"Your daily limit is used
up · Resets at midnight."** Each rule has a switch to turn it off without
deleting it (turning one off shows "*Rule* off" with **Undo**), and its row shows
where you stand — *Active now*, *22m of 30m*, *3 of 5 opens*, or *Next Mon 9 AM*.
Tap a row to edit or delete it. Deleting asks you to wait a few seconds and slide
to confirm.

Good to know:

- **A Pause lifts your rules**, just like it lifts reel blocking — it is your
  break button. Apps locked in the **App Blocker** stay locked through a Pause.
- **Unless you mark a rule Strict.** Every rule has a **Strict** switch in its
  editor. Strict rules keep blocking apps, reel feeds and websites *even during a
  Pause*. Leave it off and the rule behaves as before.
- **Time and open limits need Usage access.** Android counts app time and
  launches; without that permission a limit can't measure anything, and the
  Blocker rules screen offers a button to grant it. Detoxo re-checks your budgets about
  every 15 minutes in the background, so a limit now runs out and starts
  blocking **without you opening the app**.
- **Turning Usage access off won't unlock a limit you've already used up.** It
  stops new limits from being measured, but a block that's already up stays up
  for the rest of the day.
- Schedules are planned a week ahead, so they keep firing even if you don't
  open Detoxo for days.
- You can keep up to **50 rules**.

---

## 15. Insights: your real screen time

The **Insights** tab answers the question the reel counter can't: not just how
many short videos you watched, but how your whole day actually went.

The numbers come straight from **Android's own screen-time records** — the same
ones behind Settings → Digital Wellbeing — so they should match what your phone
already tells you, to within a minute or two. Detoxo doesn't estimate them and
doesn't try to be cleverer than your phone.

You'll see:

- **Today** — your **Reels** (with the all-time total) and **Blocked** counts,
  **Screen time**, with yesterday's finished total shown underneath as a plain
  reference ("Yesterday: 4h"), and **Pickups**: how many times you woke your phone,
  and when the first one was (in your phone's 12- or 24-hour clock). Detoxo
  deliberately does **not** print a screen-time percentage: today is still running,
  so measuring a part-day against a whole one would tell you you were doing
  brilliantly every single morning.
- **Distraction** — how much of it was in apps like short-video, social, streaming
  and games, as a time and as a share of your day, with **App switches** (how often
  your attention jumped from one app to another) and **Distracting opens**.
- **By app** — reels, blocks and screen time per app (**Reels · Blocks · Time**).
  **Tap any row to set a daily limit for that app** — it opens the rule editor
  already filled in, so the moment you notice something is the moment you can act
  on it. Nothing is saved until you pick a budget and save.
- Once you have used an override (§18), the bottom of Insights shows how many you
  have left, for example *1 override left this week*. It doesn't list what you
  spent or why.

Apps you have marked as **protected** (banking, UPI, password managers) never
appear in this list and are never written down — see §13. Their time is still
part of your total, so the number keeps matching your phone's.

Pull down to refresh. Detoxo recalculates when you open the tab, when you pull,
and when you come back to the app on a new day — there's no background tracking
and nothing runs while you're not looking.

### If you haven't granted Usage access

This screen needs the optional **Usage access** permission. Without it Detoxo
shows a **Grant** card and no numbers at all — deliberately. A screen full of
zeros would look exactly like a genuinely quiet day, and Detoxo would rather show
you nothing than something wrong. Tap **Grant** to open the Android setting; come
back and the numbers appear.

If Detoxo simply couldn't read your screen time (a hiccup rather than a refusal),
you'll get a neutral **Checking…** card with a **Retry** button that tries
again.

### A few honest caveats

- These figures count an app as "in use" whenever it's on screen, even if you
  weren't touching it. That's how Android counts it too.
- **History starts the day you first open this screen.** Android only keeps about
  a week of detailed records, so Detoxo can fill in yesterday but not last month.
  From here on it keeps the last 90 days.
- Per-app usage is **only ever stored on your device** and is never uploaded to
  Detoxo or anyone else. Detoxo also opts out of Android's cloud backup, so none of
  it is copied to your Google account (see
  [Permissions Explained](03-permissions-explained.md)).
- It's **free**. There's no paywall on knowing how you spend your own time.

---

## 16. Notification silence: stop a locked app calling you back

Blocking an app only solves half the problem. The other half is the app *reaching out* —
"3 new reels from people you follow" lands on your lock screen, you tap it, Detoxo bounces
you out, and the notification is still sitting there to tap again.

**Settings → Privacy → Notification silence** closes that loop. While it's on, an app you've
locked in the App Blocker — or one an active rule is currently blocking — simply doesn't
notify you. No sound, no banner, nothing in the shade. The moment the block lifts (your
schedule window ends, your limit resets at midnight, you start a Pause, or you turn the
switch off), its notifications come back on their own. Nothing is deleted — the app just
stops interrupting you while it's off limits.

It's **off by default** and needs one extra permission, *Notification access*, which Detoxo
explains in full before sending you to Android's screen for it. Two things worth knowing:

- **Messages and calls always come through.** Detoxo silences the feed, not the person — a
  DM, a call, an email, an alarm or a calendar reminder reaches you even from an app that's
  locked. It's the same idea as the rest of Detoxo: you keep the app, you lose the
  bottomless part.
- **Android has no "just these apps" option here.** Granting notification access technically
  exposes every notification on your phone. Detoxo reads two things — *which app sent it*
  and *whether the app marked it as a message, call or alarm* — and never the title, the
  text, the sender or the images. Nothing is saved, logged, or sent anywhere. Turn the
  switch off and Detoxo stops receiving notifications altogether, not just ignoring them.
- **Your protected apps are never touched** (§13). A banking or password app keeps notifying
  you no matter what else is switched on.

Detoxo also nudges you toward it: once you've locked your first app in the App Blocker,
that screen points out that locked apps can still notify you, with a shortcut to the switch.

One thing to know: an app that doesn't label its notifications at all has everything
silenced while it's blocked. Most big apps label messages correctly; a few don't.

---

## 17. Soft nudge: a word, not a wall

Everything else in Detoxo is a yes or a no. That's right for reels — there's no such thing as
"a little bit" of an infinite feed — but it's wrong for the app you *do* want to keep, just
less of. Block it and you'll turn the block off within a week.

**Settings → Protection → Soft nudge** is the setting in between. Nothing is blocked. Open a
distracting app and it opens, normally, like any other. Stay in it and after five minutes a
small card slides up from the bottom: *Instagram · 5m* — *Good time to put it down?* — with
one button, **Leave**, which takes you to your home screen if you want it to.

That's all it does. It doesn't close the app, press back, or take over your screen — you can
keep scrolling straight past it, because touches anywhere outside the card go to the app
underneath. It disappears on its own after six seconds, or the moment you tap it or its close button.
The card follows Detoxo's light or dark theme and stays solid, so it is easy to read over any
feed.

Stay longer and it comes back at ten minutes, and at fifteen. Leave the app for a minute and
the clock resets — come back and you start from zero.

Worth knowing:

- **It's five minutes *in one sitting*, not five minutes today.** Two four-minute visits won't
  nudge you. If what you want is "tell me once I've spent 30 minutes today", that's a
  different feature and Detoxo already has it — set a **Time limit** in Blocker rules (§14).
- **It stops after four cards per app per day**, so it can't turn into background noise. You
  can change that, and the five minutes, under **Nudge me every** in the same place.
- **You choose nothing app by app.** Detoxo already knows which apps are the distracting
  ones, and nudges those. Your protected apps (§13) are never nudged, and neither is anything
  Detoxo classes as productive.
- **It works even with blocking switched off**, because it isn't blocking — it's just telling
  you the time. And it never appears on top of a block screen: one interruption per moment.

It's off until you turn it on, and it needs the same "display over other apps" permission the
reel counter bubble uses. If that permission isn't granted, the nudge just stays quiet.

## 18. Let yourself in for a bit — and lock the rules you mean

Two things arrived together, because either one alone makes the app worse.

### "Unblock Instagram for 15 minutes"

Until now every way out of Detoxo was all-or-nothing. Need Instagram for two minutes to answer
one message? Your only option was to lift protection on **everything** — reels, every other app,
every blocked site — and hope you remembered to put it back.

Now you can free **one thing**. Tap the timer button on the blocked app's row (or **Allow for a
while** right on the block screen itself). Detoxo asks **Unblock Instagram?**: pick 5, 15, 30 or
60 minutes (5 is picked for you), take the five-second breath it asks for, then slide to unblock.
That one app — or that one feed, or that one site — opens, and a short note confirms it.
Everything else stays exactly as protected as it was.

- **It ends by itself.** Detoxo puts the block back when the time is up, even if you never open
  the app again, and even if your phone restarts in the middle. Moving your phone's clock back
  won't buy you extra time.
- **Done early?** **Block now** (on an app row, and under Blockers on Today) or **Resume** (on a
  site row) gives protection back straight away instead of waiting out the clock.
- **You never leave the app to do it.** The block screen's **Allow for a while** shows the
  durations right there (5 minutes is picked), with the same five-second breath and slide — no
  switching to Detoxo, no PIN, no round trip.
- **One place lists what's open.** Under the **Blockers** heading on Today, each thing you've
  allowed gets a row with its name, *Allowed until 5:30 PM* and a **Block now** button. The
  rows go away when nothing is allowed.
- **You can cap how often.** Under **Settings → Protection → Allowances** you can limit yourself
  to 1, 2, 3 or 5 a day. It ships as *Unlimited*, so nothing changes unless you ask for it. The
  sheet shows how many you have left, and once they are gone Detoxo says so straight away
  instead of making you wait and slide first.
- **The row tells you where you stand** — *Allowed until 5:30 PM* — and stops saying so the
  moment it lapses.
- **A Pause is still a Pause.** It lifts reels and websites the way it always did; it does not
  open a whole-app lock. Unblocking one app is the new, narrower door.
- **Adult sites are never in this.** If you have 18+ blocking on, no unblock reaches it, and
  the button doesn't appear on that screen.

### Locked rules

The other half. Any rule in **Blocker rules** (§14) can be **locked** when you make it — and a locked
rule has no off switch. Not greyed out; gone. You can't disable it, you can't delete it, and a
Pause doesn't lift it — and the parts that would let you quietly gut it are frozen too: you
can't drop apps from it, you can't move its hours to 3 a.m., and you can't drag a 30-minute
limit up to four hours. You can still rename it, and you can always make it *cover more*.

Detoxo asks once before you do it, in plain words, because it means it.

**"Cover every distracting app"** is worth knowing about: a lock that only covers the apps you
listed on Tuesday is defeated by installing a new one on Wednesday. Turn this on and the rule
holds over every app Detoxo knows to be distracting, including ones you haven't installed yet.

### The way through: an override

A lock you can never escape is a lock you escape by uninstalling the app, so there's an honest
door — it just costs something. You get **two overrides a week**. Spending one means naming a
reason (feeling unwell, medical appointment, family, your schedule changed, you set the rule up
wrong, or something else), then choosing how long, up to an hour, on a sheet that reminds you how
many overrides you have left this week, and sliding to lift the rule.

Then that **one rule** steps aside for exactly that long. Not your other rules, not your app
blocks, not anything else — and it comes back on time whether or not Detoxo is running. The rule
shows *Lifted to 5:30 PM* while it's open.

If you're out of overrides, Detoxo tells you when the next one arrives. And if the rule isn't
actually blocking right now — a schedule that's closed, a daily limit you haven't spent — Detoxo
won't let you burn one: it says so instead, because you'd be paying for a door that's already
open. There's no PIN on top of any of this either: the quota *is* the friction, and stacking two
gates on one decision just annoys you twice.

**The one thing to be clear about before you lock something:** there is no unlock. If you also
have uninstall protection on, the only way to remove a locked rule is **Settings → Reset app
data** (which clears everything Detoxo has stored), or turning Detoxo's accessibility permission
off in Android Settings. That's the deal, and it's the point.

---

## Related

- Engineering deep-dives (for the curious): [../code_docs/05-plans-pause-conscious.md](../code_docs/05-plans-pause-conscious.md),
  [../code_docs/06-app-and-web-blocker.md](../code_docs/06-app-and-web-blocker.md),
  [../code_docs/07-daily-limit-scheduler.md](../code_docs/07-daily-limit-scheduler.md),
  [../code_docs/27-rules-engine.md](../code_docs/27-rules-engine.md),
  [../code_docs/08-pin-lock-recovery.md](../code_docs/08-pin-lock-recovery.md),
  [../code_docs/13-onboarding-permissions.md](../code_docs/13-onboarding-permissions.md),
  [../code_docs/17-content-counter.md](../code_docs/17-content-counter.md),
  [../code_docs/28-insights.md](../code_docs/28-insights.md),
  [../code_docs/20-help-support.md](../code_docs/20-help-support.md).
- Other user guides: [Product Overview](01-product-overview.md) ·
  [Permissions Explained](03-permissions-explained.md) · [FAQs](04-faqs.md).
