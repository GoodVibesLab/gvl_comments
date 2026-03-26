# SDK Flutter - gvl_comments

SDK Flutter pour intégrer les commentaires GoodVibesLab dans une app. Publié sur pub.dev.

## Version actuelle : 0.9.7

## API publique

```dart
// Initialisation (singleton)
await CommentsKit.initialize(installKey: 'cmt_live_xxx');
final kit = CommentsKit.I();

// Opérations
kit.listByThreadKey(threadKey, user, limit: 50, cursor: cursor)
kit.post(threadKey: key, body: text, user: user)
kit.report(commentId: id, user: user, reason: reason)
kit.setCommentReaction(commentId: id, reaction: 'like', user: user)
kit.identify(user: user)       // Sync profil (best-effort)
kit.invalidateToken()          // Changement d'utilisateur
kit.dispose()

// Widget principal
CommentsList(
  threadKey: 'post:abc123-uuid',
  currentUser: UserProfile(id: 'user1', name: 'Alice'),
  // Builders optionnels : commentItemBuilder, avatarBuilder, composerBuilder
)
```

## Structure

```
lib/
  gvl_comments.dart              # Exports publics
  comments_client.dart           # Legacy CommentsClient
  comments_logger.dart           # Export logger
  src/
    gvl_comments.dart            # CommentsKit singleton (coeur du SDK)
    models.dart                  # CommentModel, UserProfile, ModerationSettings
    api_client.dart              # Wrapper HTTP (getRaw, getJson, postJson)
    token_store.dart             # Cache JWT en mémoire avec expiry
    comments_config.dart         # Détection plateforme/version
    comments_config_io.dart      # Bindings natifs (Android SHA256, iOS Team ID)
    comments_config_stub.dart    # Stub web
    utils/
      comments_logger.dart       # Niveaux : off, error, info, debug, trace
      time_utils.dart            # Timestamps relatifs ("il y a 5 min")
    widgets/
      comments_list.dart         # Widget principal (liste + composer)
      comment_reactions_bar.dart # Barre de réactions (style Messenger)
      comments_error_view.dart   # Vue d'erreur avec retry + debug code
      linked_text.dart           # Détection URLs dans le texte
  l10n/
    gvl_comments_en.arb          # Strings anglais
    gvl_comments_l10n.dart       # Interface i18n
    gvl_comments_l10n_en.dart    # Implémentation EN
```

## Architecture

- **Dual token store** : tokens thread-scoped (list/post) et meta-scoped (identify/react/report)
- **Optimistic UI** : commentaire affiché immédiatement, remplacé par la réponse serveur
- **Cursor pagination** : opaque via header `x-next-cursor`
- **App binding** : SHA-256 Android + Team ID iOS envoyés au token endpoint
- **Cooldown** : 60s après erreur de binding invalide

## Réactions

6 types : like, love, laugh, wow, sad, angry. Une par user par commentaire.
UI Messenger-like avec toggle au tap et picker au long press.

## Thèmes

Presets disponibles : `.defaults()`, `.neutral()`, `.compact()`, `.card()`, `.bubble()`
Extends `ThemeExtension<GvlCommentsThemeData>`.

## Thread keys

Format requis : 20+ chars, alphanum + `:_-.`, haute entropie (UUID/ULID).
Rejetés en prod : `post-123`, tout numérique, patterns devinables.

## Localisation

```dart
MaterialApp(
  localizationsDelegates: GvlCommentsL10n.localizationsDelegates,
  supportedLocales: GvlCommentsL10n.supportedLocales,
)
```

## Dépendances clés

- `http` (requêtes réseau)
- `intl` (i18n)
- `crypto` (SHA-256 pour bindings)
- `meta` (annotations)
