---
name: detoxo-code-quality
description: Architecture and code-quality review engine for one Detoxo module — validates Clean Architecture layering and feature boundaries, SOLID, meaningful reuse, simplicity, scalability, lint compliance, state-management and error-handling shape, Flutter rebuild/lifecycle hygiene — with evidence from the code, a measurable scorecard (never an arbitrary score), and incremental verified refactors. Use when asked to review, audit, clean up, refactor, simplify, de-duplicate, or judge the architecture, SOLID compliance, code quality, maintainability or scalability of a screen, feature or module. Triggers: "review the architecture of X", "is X clean / SOLID", "code quality of this module", "find duplication in X", "simplify this screen", "refactor X safely", "is this maintainable", "/detoxo-code-quality".
---

# detoxo-code-quality — the feature works *and* the code will still be good in a year

Companion to `/detoxo-auto-test` (does it work?) and `/detoxo-evolution` (what should it become?).
This skill answers: **is the module correctly built?** It is module-scoped, evidence-driven, and
it never trades one quality for another silently.

## Detoxo's architecture is the spec, not a generic one

Discover the structure from the code, then hold the module to *this* project's rules:

| Rule | Where it is enforced |
|---|---|
| Feature-first Clean Architecture: `lib/features/<x>/{data,domain,presentation}` reached only via the barrel `features/<x>/<x>.dart` or another feature's `domain/` | `tool/check_boundaries.sh` — `tool/boundaries_baseline.txt` is **empty** (burned down in M6), **0 new allowed, never add to the list** |
| Composition roots exempt from boundaries: `lib/app`, `lib/core/{di,navigation}`, `features/dashboard` (shell), `features/settings` (orchestrator) | same script |
| State: **flutter_bloc Cubit** only, DI via **get_it `sl`**, routing via **go_router**. No Riverpod, no event-mega-blocs | `CLAUDE.md` |
| Shared code lives in `lib/core/{design_system,widgets,utils,error,storage,services,…}`; a widget used by two features belongs there, not copied | convention |
| Hot detection/block path is native Kotlin; Dart owns config, settings, UI. One MethodChannel + one EventChannel | `CLAUDE.md` |
| Lint: `flutter_lints` + strict casts/inference/raw-types + curated rules (`unawaited_futures`, `close_sinks`, `cancel_subscriptions`, `use_build_context_synchronously`, `always_use_package_imports`, …) | `analysis_options.yaml` — never disable a rule to pass; document a justified `// ignore:` with the reason |
| Names: only **Detoxo** / **errorxperts**; wire token `"CURIOUS"` verbatim, UI label "Conscious" | `CLAUDE.md` |

## Workflow

**1. Scope one module.** From the chat or `git status --porcelain`. Read in this order and stop
when the scope is covered: barrel → presentation (screen, widgets, cubit + state) → domain
(entities, use cases, contracts) → data (models, repository impls, Hive / secure storage /
platform channel). Then the module's tests. Do not read unrelated features.

**2. Draw the dependency graph** for the module — five lines, not a diagram tool:

```text
<Feature>
 ├── depends on: <core/…>, <other feature>.domain, native channel?
 ├── depended on by: <features importing its barrel>
 └── flags: circular? reaches into another feature's data/presentation? hidden (sl.get inside a widget)?
```

**3. Check, with a file:line for every finding.** No finding without evidence.

- **Layering** — business logic or Hive access inside a widget; model leaking into presentation
  when an entity exists; UI calling a data source; a repository impl living under `domain/`;
  domain code importing `package:flutter`; the same rule implemented in two screens.
- **SOLID** — SRP: a screen or cubit doing UI + validation + persistence + navigation. OCP: every
  new mode/plan/rule needs an edit to a `switch` in five places. LSP: an impl that throws
  `UnimplementedError` on part of its contract. ISP: a fat repository interface where consumers
  use two methods. DIP: a cubit constructing its own repository or data source.
- **Reuse** — duplicate widgets, validators, formatters, navigation snippets, constants, helper
  functions across the module or against `lib/core`. Extract only when responsibilities match
  *now* and will keep matching; two things that merely look alike stay separate.
- **Simplicity** — nested conditions > 3 deep, methods > ~60 lines, complex booleans, unnecessary
  temporaries, wrappers with one caller, inheritance where composition fits, state that is
  derivable from other state, rebuild triggers with no reader. The goal is the simplest correct
  implementation, not the fewest lines.
- **Scalability** — "if this feature grew 5×, what breaks first?" Look at the feature boundary,
  dependency direction, cubit state shape, repository surface, navigation, shared infrastructure.
- **Lint & static** — `flutter analyze` on the module's paths; plus deprecated APIs, unused
  imports/variables, unsafe casts, missing `const`, `debugPrint` left in, dead code, unhandled
  futures, `BuildContext` across an `await`.
- **Consistency** — intention-revealing names (no `data`, `temp`, `obj`, `doSomething`); screens
  split into header / content sections / actions only where those are real responsibilities;
  file names match class names; one style per module.
- **Flutter performance** — `const` constructors, rebuild scope (`BlocBuilder` `buildWhen`,
  `BlocSelector`, `context.select`), `ListView.builder` for unbounded lists, controller and
  stream `dispose`, expensive work inside `build`, image sizing, animation controllers lifecycle.
  Trace the chain: *small state change → which widgets rebuild?*
- **State** — one owner per piece of state; loading / success / error / empty / initial all
  represented; immutable state (freezed); no global cubit for local UI state and no
  `StatefulWidget` field for app-wide state; no duplicate sources of truth.
- **Errors** — infrastructure error → domain failure → cubit state → user feedback, consistently;
  no swallowed `catch (_) {}`, no bare `catch (e)` re-thrown as a string, no platform exception
  reaching a widget untranslated, no silent failure on a persistence write.

**4. Prioritise, then fix incrementally.**

```text
P0 correctness / critical bug   P1 crash / data integrity   P2 significant performance
P3 architecture / maintainability   P4 reusability   P5 simplification   P6 style
```

Apply **P0–P2 and any behaviour-preserving P3–P6 that stays inside the module** directly, one
change at a time: smallest improvement → `flutter test test/<module>_test.dart` → new test for
the finding when logic changed → `flutter analyze` → `bash tool/check_boundaries.sh`. Structural
refactors (moving code across layers, new contracts, touching another feature, anything that
changes a public barrel) are **proposed, not applied**, in this shape:

```text
Current implementation:   <file:line, what it does>
Architectural problem:    <which rule above>
Why it matters:           <concrete consequence>
Recommended structure:    <target shape>
Refactoring:              <steps, smallest first>
Regression risk:          <what could break, which tests cover it>
```

Never make a shortcut that violates layering or SOLID to get a test green or a diff smaller.
Never perform a large refactor without running the module's tests between steps.

**5. Verify and finish.** `bash tool/dev.sh precommit` once at the end (format → analyze → test →
native tests → boundaries). If the module or its native counterpart changed, run `/docs-sync`.

## Definition of done

A module is reviewed only when every row has been looked at and either has a finding or an
explicit "clean": layering · SOLID · reuse · simplicity · scalability · lint · consistency ·
Flutter performance · state · errors · lifecycle/memory · test gaps · existing tests run · new
tests run · applied fixes verified.

## Scorecard (measured, never an overall number)

```text
MODULE                         <name>  (<n> files read)
Clean Architecture violations  X   <file:line …>
Boundary violations (new)      X   must be 0
SOLID concerns                 X
Duplicate implementations      X
Large classes (> ~300 lines)   X
Large methods (> ~60 lines)    X
Lint issues                    X   (flutter analyze on module paths)
Deprecated APIs                X
Performance concerns           X
Memory / lifecycle concerns    X
Error-handling gaps            X
Test gaps                      X
APPLIED   <fix → verification>
PROPOSED  <P-level, one line each; full block above on request>
TRADE-OFFS <any quality traded for another, stated explicitly>
```

## Never

- Never add to `tool/boundaries_baseline.txt`; never disable a lint to pass the analyzer.
- Never abstract for its own sake: no interface with one implementation, no shared widget for two
  screens whose behaviour will diverge, no config for a value that never changes.
- Never report a finding without a file:line, or a "clean" row you did not actually check.
- Never change behaviour while refactoring; if a test must change, the finding was P0, say so.
- Never optimise one dimension (fewer lines, faster frames, purer layering) at the cost of
  another without naming the trade-off in the scorecard.
