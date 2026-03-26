# Changelog

All notable changes to the **GoodVibesLab Comments Client (Flutter)** package will be documented here.

## 1.0.0

First stable release. The public API is now frozen under semantic versioning.

### Breaking changes
- **`CommentModel.status`** is now a `CommentStatus` enum. Use `comment.commentStatus` for type-safe comparisons. The legacy `comment.status` getter still returns a `String` for backward compatibility.
- **`GvlCommentsStrings.fr()` factory removed** — use the l10n system (`GvlCommentsL10n`) for localization instead.

### Added
- **`TopComment` widget** — displays the single most-engaged comment for a thread. Supports full builder customization (`builder`, `loadingBuilder`, `emptyBuilder`, `errorBuilder`).
- **`CommentCount` widget** — displays the approved comment count for a thread. Reads from cache when `prefetchThreads` was called (zero latency).
- **`CommentsKit.prefetchThreads()`** — batch-fetches thread info (count + top comment) for multiple threads. Ideal for feed/list performance.
- **`CommentsKit.topComment()`** / **`CommentsKit.commentCount()`** — individual API accessors with cache support.
- **`ThreadInfo` model** — holds prefetched count + top comment data.
- **`CommentStatus` enum** (`pending`, `approved`, `rejected`) — replaces string constants.
- **`Reaction` enum** (`like`, `love`, `laugh`, `wow`, `sad`, `angry`) with `id`, `emoji`, and `emojiFor()` helper.
- **`LoadMoreButtonBuilder`** parameter on `CommentsList` — fully customize the pagination button.
- **Threaded replies** (depth 2) with `parentId`, `replyToCommentId`, `replyToUserId` on `CommentModel`.
- **Localized reaction labels** — reaction picker labels (`Like`, `Love`, etc.) now go through `GvlCommentsL10n`.
- **4 new locales** — German (de), Spanish (es), French (fr), Portuguese (pt) alongside English.
- **HTTP request timeout** (15 s) on all API calls — prevents indefinite hangs.
- **Body validation constants** — `CommentsKit.minBodyLength` (1) and `CommentsKit.maxBodyLength` (5000) exposed publicly.
- **`topics`** field in pubspec.yaml for pub.dev discoverability.
- **`.pubignore`** to reduce published package size.

### Deprecated
- **`CommentsClient`** (legacy API) — use `CommentsKit` instead. Will be removed in 2.0.
- **`Comment`**, **`CommentsExternalUser`**, **`CommentsUserRole`**, **`CommentsApiException`** — use their modern counterparts.
- **`CommentModel.statusPending/statusApproved/statusRejected`** string constants — use `CommentStatus` enum.

### Fixed
- iOS podspec had a duplicate `Pod::Spec.new` block (now consolidated).
- Android `build.gradle` version aligned to `1.0.0`.
- Hardened user identification flow (from 0.9.7).

## 0.9.7

### Fixed
- Hardened user identification flow


## 0.9.6

### Security
- Added **optional strict install key binding** for enhanced application security:
    - **Android**: app signing certificate **SHA-256**
    - **iOS**: **Team ID**
- Clear and explicit authentication errors when strict binding is enabled and the app signature does not match.
- Improved protection against API key reuse across unrelated applications.

### Added
- New **production-grade error UI** for comments:
    - Retry action
    - Stable debug / support code
    - Optional expandable technical details panel
- Improved token request headers including platform, package name, and app version.

### Improved
- SDK initialization and runtime configuration flow.
- Internal logging and diagnostics for easier production debugging.
- Android plugin configuration for wider consumer compatibility.
- More robust handling of authentication and moderation failures (non-fatal where possible).

### Internal
- Plugin scaffold cleanup and release-ready project structure.
- iOS podspec metadata updated.
- iOS privacy manifest (`PrivacyInfo.xcprivacy`) included.
- Web compatibility improved via conditional platform imports.

## 0.9.5
- Added comment reactions (like, love, etc.) with optimistic UI
- Improved visual polish and interaction feedback
- Better defaults for spacing, bubble layout, and composer
- Overall stability and UX improvements

## 0.9.4
- Example app now runs out-of-the-box with a built-in demo install key

## 0.9.3
- Added debug-only SDK logs (`gvl_comments:` prefix)
- Clear initialization log on startup
- Improved error diagnostics for missing or invalid install key
- Safe obfuscation of sensitive values in logs (API key, user id)
- Better resilience when authentication fails (non-fatal identify)
- Minor UI improvements

## 0.9.2
- Fix external link handling (URLs without scheme now open correctly)
- Improve composer layout and safe-area padding
- Better avatar rendering
- Minor visual refinements for comment bubbles and input

## 0.9.1
- Initial public release on pub.dev
- Added install key initialization + platform binding headers
- Included example app (Android + iOS)

## 0.9.0 — 2025-12-09

### 🚀 Initial Production Release  
- First production‑ready release of the **GVL Comments Flutter SDK**.  
- Fully compatible with the GoodVibesLab Comments SaaS platform.  
- Public API validated and stabilized for production apps.

### ✨ Features  
- Comment listing with cursor‑based pagination.  
- Comment posting with hydrated server response.  
- Real‑time profile sync: name + avatar resolved automatically from token.  
- Moderation states:
  - `pending`, `approved`, `rejected`
  - `is_flagged` (AI or user report)
  - Helpers: `isReported`, `isModerated`
- UI widgets:
  - `GvlCommentsList` (full thread viewer)
  - Built‑in composer with send button
  - Customizable builders: avatar, item, composer, separators
- Server filtering:
  - Deleted comments never returned  
  - AI‑rejected comments replaced by placeholder  

### 🔐 Moderation & Reporting  
- User report flow with duplicate prevention.  
- AI moderation states surfaced in UI.  
- Auto‑hide, soft‑hide, and hard‑hide behaviors handled by backend + SDK helpers.

### 🎨 Theming & UI  
- Complete theming system: `GvlCommentsTheme` + `GvlCommentsThemeData`.  
- Presets included: `defaults`, `neutral`, `compact`, `card`, `bubble`.  
- Owner and others now aligned left (Facebook‑style layout).  
- Avatar aligned **top**, not center.  
- Long usernames ellipsized cleanly.  
- New **relative timestamps** ("just now", "il y a 3 min").  
- Clickable URLs + email detection.  
- Spacing & vertical rhythm refinement for cleaner reading.  
- Light fade/slide animation on comment appear.  
- Optimistic UI state: pending comments appear with opacity until server confirms.

### 👤 Avatars  
- Default avatar logic introduced:  
  - If `avatarUrl` → load `Image.network`  
  - On failure → fallback initial  
  - If avatarBuilder provided → use custom implementation  

### 🧰 Internal Improvements  
- Stronger JSON validation & safer parsing.  
- Unified contract with React SDK.  
- Cleaner error handling.  
- Debug logs improved & standardized.  
- Token now exposes plan to allow conditional branding.  

### 🏷️ Branding  
- Free‑tier apps automatically display  
  **"Comments powered by GVL Cloud"**  
  with tappable logo and external link.

---

Future releases will follow **semantic versioning** (`MAJOR.MINOR.PATCH`).  
