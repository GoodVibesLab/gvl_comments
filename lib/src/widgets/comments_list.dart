import 'package:flutter/material.dart';
import '../gvl_comments.dart';
import '../models.dart';

class GvlCommentsList extends StatefulWidget {
  final String threadKey;
  final UserProfile user; // <- on reçoit l’utilisateur ici

  const GvlCommentsList({
    super.key,
    required this.threadKey,
    required this.user,
  });

  @override
  State<GvlCommentsList> createState() => _GvlCommentsListState();
}

class _GvlCommentsListState extends State<GvlCommentsList> {
  List<CommentModel>? _comments;
  String? _error;
  final _ctrl = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  String? _lastUserId; // pour détecter un changement d’utilisateur

  @override
  void initState() {
    super.initState();
    _primeAndLoad();
  }

  @override
  void didUpdateWidget(covariant GvlCommentsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      // utilisateur changé -> on invalide le JWT et on recharge
      CommentsKit.I().invalidateToken();
      _primeAndLoad();
    } else if (oldWidget.threadKey != widget.threadKey) {
      _load();
    }
  }

  Future<void> _primeAndLoad() async {
    _lastUserId = widget.user.id;
    await _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final kit = CommentsKit.I();
      final list = await kit.listByThreadKey(
        widget.threadKey,
        limit: 50,
        user: widget.user,
      );
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
      final kit = CommentsKit.I();
      final created = await kit.post(
        threadKey: widget.threadKey,
        body: text,
        user: widget.user,
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

    final comments = _comments ?? [];

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            reverse: true,
            itemCount: comments.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = comments[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                title: Text(
                  c.authorName ?? c.externalUserId,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(c.body),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sending ? null : _send(),
                  decoration: const InputDecoration(
                    hintText: "Ajouter un commentaire...",
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
}