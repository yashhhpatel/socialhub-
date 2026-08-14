import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_message.dart';
import '../../../../core/theme/tokens/spacing_tokens.dart';
import '../../data/repositories/api_collaboration_repository.dart';
import '../../domain/entities/comment.dart';

/// The editor's comment sidebar (Milestone 13.3) — the design's feedback
/// thread, opened as an end-drawer. Oldest at the top (as the API returns
/// them); a field at the bottom adds to the thread.
class CommentsDrawer extends ConsumerStatefulWidget {
  const CommentsDrawer({super.key, required this.assetId});

  final String assetId;

  @override
  ConsumerState<CommentsDrawer> createState() => _CommentsDrawerState();
}

class _CommentsDrawerState extends ConsumerState<CommentsDrawer> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(collaborationRepositoryProvider).addComment(widget.assetId, body);
      _controller.clear();
      ref.invalidate(commentsProvider(widget.assetId));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not post comment: ${describeApiError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commentsAsync = ref.watch(commentsProvider(widget.assetId));

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(SpacingTokens.md),
              child: Row(
                children: [
                  Icon(Icons.forum_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: SpacingTokens.sm),
                  Text('Comments', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: commentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(describeApiError(e))),
                data: (comments) => comments.isEmpty
                    ? const Center(child: Text('No comments yet.'))
                    : ListView(
                        padding: const EdgeInsets.all(SpacingTokens.md),
                        children: [for (final c in comments) _CommentTile(comment: c)],
                      ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(SpacingTokens.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment…',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.xs),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = comment.createdAt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(comment.authorEmail, style: theme.textTheme.labelMedium),
              ),
              Text(
                '${local.day}/${local.month} $hh:$mm',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(comment.body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
