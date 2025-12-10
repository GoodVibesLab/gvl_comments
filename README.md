# GoodVibesLab Comments Client (Flutter)

A production‑ready Flutter client for the **GoodVibesLab Comments SaaS** — offering fast, multi‑tenant comments with moderation, AI review, reporting, pagination and customizable UI.  

This package is used internally across all GVL apps and is now available with a **Free Tier** so developers can try the service without paying.  
To use the SDK, users must create an account on the dashboard to obtain an API key.

---

## 🚀 Features

- ⚡ Ultra‑fast comment loading (Supabase + Edge)
- 🔐 Tenant‑isolated data with strict RLS
- 🧪 AI moderation (optional)
- 📣 User reporting + soft/hard hide thresholds
- 🗂 Pagination with cursor-based loading
- 🧵 Threaded comments, avatars, custom builders
- 🛠 Server‑hydrated responses with avatars & profiles

---

## 🆓 Free Tier

A **100% Free Tier** is available so you can evaluate the service:

- 1 project  
- Limited monthly comment volume  
- Full API access  
- Dashboard & moderation tools  
- Requires creating an account to obtain an API key

Upgrade plans unlock higher volumes, auto‑moderation, analytics and priority performance.

Create your free account at:

**https://goodvibeslab.cloud**

---

## 📦 Installation

Add the package locally or via pub.dev:

```yaml
dependencies:
  comments_client:
    path: packages/comments_client
```

Then:

```sh
flutter pub get
```

---

## 🔧 Setup

1. Create an account on the dashboard.
2. Retrieve your **API key** (starts with `cmt_live_XXX`).
3. Get your **Thread ID** (UUID) from the dashboard.
4. Instantiate the client:

```dart
final client = CommentsClient(
  baseUrl: 'https://your-deployment.vercel.app',
  apiKey: 'cmt_live_xxx',
  externalUser: CommentsExternalUser(
    id: 'user-123',
    name: 'Ada Lovelace',
    avatarUrl: 'https://example.com/avatar.png',
  ),
);
```

---

## 💬 Listing Comments

```dart
final comments = await client.listComments(
  threadId: '4e9e9b31-bbe2-4e62-a836-8d361521b3a0',
);
```

---

## ✍️ Creating a Comment

```dart
final created = await client.createComment(
  threadId: '4e9e9b31-bbe2-4e62-a836-8d361521b3a0',
  body: 'First! 🎉',
);
```

---

## 🧵 About Thread Identifiers

The REST API **requires the internal UUID**, not the user‑friendly thread key.  
You can retrieve it from:

- the dashboard, or  
- the admin API if you manage threads programmatically.

The client automatically injects:

- `tenant_id`  
- `external_user_id`  
- `user profile fields`  

No manual boilerplate needed.

---

## 📄 Example

See the full working example here:

```
example/lib/main.dart
```

---

## 🛠 Support & Production Use

This SDK is ready for production.  
For help, reach out at:

**support@goodvibeslab.cloud**

---

## 📝 License

Commercial license, included with all GoodVibesLab paid plans. A free tier is also available for testing.
