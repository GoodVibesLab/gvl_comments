import 'package:flutter/material.dart';
import 'package:gvl_comments/gvl_comments.dart';

class GvlCommentsList extends StatefulWidget {
  final String threadKey;
  const GvlCommentsList({super.key, required this.threadKey});

  @override
  State<GvlCommentsList> createState() => _GvlCommentsListState();
}

class _GvlCommentsListState extends State<GvlCommentsList> {
  List<CommentModel>? _comments;
  String? _error;
  final _ctrl = TextEditingController();
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await CommentsKit.I().listByThreadKey(widget.threadKey, limit: 100);
      setState(() {
        _comments = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() { _sending = true; _error = null; });

    try {
      // NOTE: l’utilisateur doit avoir été bind ailleurs via:
      // await CommentsKit.I().setUser(const UserProfile(id: '...', name: '...'));
      final created = await CommentsKit.I().post(
        threadKey: widget.threadKey,
        body: text,
      );
      setState(() {
        _comments = [created, ...(_comments ?? [])];
        _ctrl.clear();
      });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _sending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Erreur', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    final comments = _comments ?? const <CommentModel>[];

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            reverse: true, // derniers en haut si tu veux le flux "chat"
            itemCount: comments.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = comments[i];
              return ListTile(
                dense: true,
                title: Text(
                  (c.authorName ?? 'Utilisateur'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(c.body),
                trailing: Text(
                  _fmtTime(c.createdAt),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sending ? null : _send(),
                  decoration: const InputDecoration(
                    hintText: "Ajouter un commentaire…",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Envoyer'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtTime(DateTime dt) {
    // Mini format local sans intl pour l’instant
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}