import 'package:flutter/material.dart';
import '../gvl_comments.dart';
import '../models.dart';

class GvlCommentsList extends StatefulWidget {
  final String threadKey;
  const GvlCommentsList({super.key, required this.threadKey});

  @override
  State<GvlCommentsList> createState() => _GvlCommentsListState();
}

class _GvlCommentsListState extends State<GvlCommentsList> {
  List<CommentModel>? _comments;
  final _ctrl = TextEditingController();
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final kit = GvlComments();
    final list = await kit.fetchComments(widget.threadKey);
    setState(() {
      _comments = list;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final kit = GvlComments();
    final created = await kit.post(widget.threadKey, text);
    setState(() {
      _comments = [created, ..._comments ?? []];
      _ctrl.clear();
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final comments = _comments ?? [];

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            reverse: true,
            itemCount: comments.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) {
              final c = comments[i];
              return ListTile(
                title: Text(c.authorName ?? c.externalUserId,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  decoration: const InputDecoration(
                    hintText: "Ajouter un commentaire...",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Envoyer'),
              )
            ],
          ),
        )
      ],
    );
  }
}