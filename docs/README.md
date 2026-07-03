# Detoxo — Documentation

Documentation for **Detoxo**, an Android-first short-form-content (Reels / Shorts / infinite-feed)
**blocker + on-device reel counter** built in **Flutter (flutter_bloc + get_it + go_router,
feature-first Clean Architecture)** with a native **Android AccessibilityService** engine
(`com.errorxperts.detoxo`).

These docs are written **from the shipped source code**. Two audiences, two folders:

## 📘 [`code_docs/`](code_docs/) — engineering
How the app actually works: architecture, the native detection/block engine, config schema,
plans, blockers, persistence, the channel contract, and the build's status. Start at
[`code_docs/00-index.md`](code_docs/00-index.md).

## 📗 [`info_docs/`](info_docs/) — end-user & marketing
What Detoxo does, how to use each feature, why each permission is needed, and FAQs. Start at
[`info_docs/00-index.md`](info_docs/00-index.md).

---

### Keeping docs in sync
When code changes, the matching doc changes with it. The feature→doc mapping and update
checklist live in [`.claude/skills/docs-sync/SKILL.md`](../.claude/skills/docs-sync/SKILL.md)
(run `/docs-sync`); the rule is summarized in the project [`CLAUDE.md`](../CLAUDE.md).
