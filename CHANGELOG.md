# Changelog

All notable changes to the **GoodVibesLab Comments Client (Flutter)** package will be documented here.

## 0.9.0 — 2025-12-09

### 🚀 Initial Production Release
- First stable, production‑ready version of the GVL Comments Flutter SDK.
- Full integration with the GoodVibesLab Comments SaaS platform.
- Public API stabilized and documented.

### ✨ Features
- Comment listing with cursor‑based pagination.
- Comment posting with automatic hydration and profile sync.
- Moderation states:
  - `pending`, `approved`, `rejected`
  - `is_flagged` (AI or user reports)
  - `isReported` / `isModerated` helpers
- UI widgets:
  - `GvlCommentsList` (thread view)
  - Composer + send button
  - Customizable item, avatar, composer builders
- Automatic token handling & caching.
- Thread auto‑creation by key on first comment.
- Profile sync via JWT (`external_user_id`, `user_name`, avatar).
- Localizable placeholders: reported / moderated messages.
- Server‑side filtering: hidden & deleted comments no longer exposed.

### 🔐 Moderation & Reporting
- Automatic handling of AI‑flagged comments.
- User reporting with duplicate‑report protection.
- Soft‑hide & hard‑hide logic integrated with SDK helpers.

### 🎨 Theming
- Full theming system via `GvlCommentsTheme` & `GvlCommentsThemeData`.
- Multiple presets: `defaults`, `neutral`, `compact`, `card`, `bubble`.

### 🧰 Internal Improvements
- Unified API contract with React SDK.
- Stronger JSON validation.
- Normalized model fields (snake_case → camelCase mapping).
- Cleaned error handling & debug logging.
- SDK caching improvements.

---

Future releases will follow semantic versioning:  
**MAJOR.MINOR.PATCH**
