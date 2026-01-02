# Changelog

All notable changes to the **GoodVibesLab Comments Client (Flutter)** package will be documented here.

## 0.9.6

### Added
- Optional **strict install key binding** for enhanced security:
    - Android: app signing certificate **SHA-256**
    - iOS: **Team ID**
- Clear authentication errors when strict binding is enabled and the app signature does not match.
- New production-grade error UI for comments (retry, debug code, optional details panel).

### Improved
- Comments SDK initialization and configuration flow.
- Internal logging and error handling for easier debugging in production.
- Android plugin configuration for wider consumer compatibility.

### Internal
- Plugin scaffold cleanup and release-ready project structure.
- iOS podspec metadata updated and privacy manifest included.

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
