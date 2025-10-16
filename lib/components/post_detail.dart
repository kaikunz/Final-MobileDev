import 'package:flutter/material.dart';
import '/pocketbase_client.dart';
import '/models/models.dart';
import '/auth/login.dart';

class PostDetail extends StatefulWidget {
  final Post post;
  const PostDetail({super.key, required this.post});

  @override
  State<PostDetail> createState() => _PostDetailState();
}

class _PostDetailState extends State<PostDetail> {
  bool _loading = true;
  List<Comment> _comments = [];
  final TextEditingController _ctrl = TextEditingController();

  // local vote state for this post
  int _upvotes = 0;
  int _downvotes = 0;
  String? _myVote; // 'up' | 'down' | null
  bool _voting = false;

  @override
  void initState() {
    super.initState();
    _upvotes = widget.post.upvotes;
    _downvotes = widget.post.downvotes;
    _loadComments();
    _loadMyVote();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      // request expanded author data if available
      final recs = await pb.collection('comment').getFullList(
        // try both common field names: post / postId
        filter: 'postId = "${widget.post.id}" || postId = "${widget.post.id}"',
        expand: 'author,authorId',
      );

      final list = recs.map<Comment?>((r) {
        try {
          final json = r.toJson();
          if (json is Map<String, dynamic>) {
            // robust extraction of fields and expanded author name
            final id = json['id'] as String? ?? '';
            final postId = (json['post'] ?? json['postId']) as String? ?? '';
            final authorId = (json['author'] ?? json['authorId']) as String? ?? '';
            final content = (json['content'] ?? '') as String;
            DateTime created;
            try {
              created = DateTime.parse(json['created'] as String);
            } catch (_) {
              created = DateTime.now();
            }

            String? authorName;
            try {
              final expand = (json['expand'] as Map<String, dynamic>?) ?? {};
              final author = (expand['author'] ?? expand['authorId']) as Map<String, dynamic>?;
              if (author != null) {
                authorName = (author['username'] ??
                    author['name'] ??
                    author['displayName'] ??
                    author['email']) as String?;
              }
            } catch (_) {}

            return Comment(
              id: id,
              postId: postId,
              authorId: authorId,
              content: content,
              created: created,
              authorName: authorName,
            );
          }
        } catch (_) {}
        return null;
      }).whereType<Comment>().toList();
      setState(() => _comments = list);
    } catch (_) {
      setState(() => _comments = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMyVote() async {
    final userModel = pb.authStore.model;
    if (userModel == null) return;
    try {
      final recs = await pb.collection('vote').getFullList(
        filter: 'userId = "${userModel.id}" && (postId = "${widget.post.id}")',
      );
      if (recs.isNotEmpty) {
        final json = recs.first.toJson();
        String type = '';
        if (json['type'] is String) {
          type = json['type'] as String;
        } else if (json['value'] != null) {
          final v = (json['value'] is int) ? json['value'] as int : int.tryParse('${json['value']}') ?? 0;
          type = v > 0 ? 'up' : 'down';
        }
        if (type.isNotEmpty) {
          setState(() => _myVote = type);
        }
      }
    } catch (_) {}
  }

  Future<void> _submitComment() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final userModel = pb.authStore.model;
    if (userModel == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }

    try {
      // try both common field names; server will accept whichever is correct.
      await pb.collection('comment').create(body: {
        'postId': widget.post.id,
        'authorId': userModel.id,
        'content': text,
      });
      _ctrl.clear();
      await _loadComments();
      // optional: scroll to bottom or show snack
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ไม่สามารถโพสต์คอมเมนต์ได้')));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _vote(bool up) async {
    if (_voting) return;
    final userModel = pb.authStore.model;
    if (userModel == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }
    final userId = userModel.id;
    setState(() => _voting = true);

    try {
      final existing = await pb.collection('vote').getFullList(
        filter: 'userId = "$userId" && (postId = "${widget.post.id}" || postId = "${widget.post.id}")',
      );

      String wanted = up ? 'up' : 'down';

      if (existing.isEmpty) {
        // create
        final body = {'userId': userId, 'postId': widget.post.id, 'type': wanted};
        await pb.collection('vote').create(body: body);
        if (up) _upvotes = _upvotes + 1;
        else _downvotes = _downvotes + 1;
        setState(() => _myVote = wanted);
      } else {
        final rec = existing.first;
        final json = rec.toJson();

        String curType = '';
        if (json['type'] is String) {
          curType = json['type'] as String;
        } else if (json['value'] != null) {
          final v = (json['value'] is int) ? json['value'] as int : int.tryParse('${json['value']}') ?? 0;
          curType = v > 0 ? 'up' : 'down';
        }

        if (curType == wanted) {
          // toggle off
          await pb.collection('vote').delete(rec.id);
          if (up) _upvotes = (_upvotes - 1).clamp(0, 1 << 30);
          else _downvotes = (_downvotes - 1).clamp(0, 1 << 30);
          setState(() => _myVote = null);
        } else {
          // switch
          final updateBody = json.containsKey('type') ? {'type': wanted} : {'value': (up ? 1 : -1)};
          await pb.collection('vote').update(rec.id, body: updateBody);
          if (up) {
            _upvotes = _upvotes + 1;
            _downvotes = (_downvotes - 1).clamp(0, 1 << 30);
          } else {
            _downvotes = _downvotes + 1;
            _upvotes = (_upvotes - 1).clamp(0, 1 << 30);
          }
          setState(() => _myVote = wanted);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ไม่สามารถลงคะแนนได้')));
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  // delete comment by id with confirmation
  Future<void> _deleteComment(Comment c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบความคิดเห็น'),
        content: const Text('ต้องการลบความคิดเห็นนี้หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await pb.collection('comment').delete(c.id);
      await _loadComments();
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ไม่สามารถลบคอมเมนต์ได้')));
    }
  }

  // edit comment content (improved UI: bottom sheet, red save button, char count)
  Future<void> _editComment(Comment c) async {
    final controller = TextEditingController(text: c.content);
    String? updated;
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(builder: (ctx2, setState2) {
            var loading = false;
            void doSave() async {
              final text = controller.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('ข้อความเป็นค่าว่าง')));
                return;
              }
              setState2(() => loading = true);
              try {
                await pb.collection('comment').update(c.id, body: {'content': text});
                Navigator.pop(ctx, text);
              } catch (_) {
                setState2(() => loading = false);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('ไม่สามารถอัปเดตคอมเมนต์ได้')));
              }
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                        child: Text('แก้ไขความคิดเห็น',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx, null),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.08)),
                  ),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 8,
                    onChanged: (_) => setState2(() {}),
                    decoration: const InputDecoration(
                      hintText: 'แก้ไขข้อความ...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${controller.text.trim().length} ตัวอักษร',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ),
                    TextButton(
                      onPressed: loading ? null : () => Navigator.pop(ctx, null),
                      child: const Text('ยกเลิก'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: loading ? null : doSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('บันทึก'),
                    ),
                  ],
                ),
              ],
            );
          }),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      updated = result;
      controller.dispose();
      await _loadComments();
    } else {
      controller.dispose();
    }
  }

  // show owner actions with themed bottom sheet (edit / delete)
  Future<void> _showCommentActions(Comment c) async {
    final choice = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.black87),
                title: const Text('แก้ไข'),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('ลบ', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (choice == 'edit') await _editComment(c);
    if (choice == 'delete') await _deleteComment(c);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = pb.authStore.model?.id;
    // prefer name -> email -> username -> id for display — handle RecordModel safely
    String meDisplay = 'U';
    final model = pb.authStore.model;
    if (model != null) {
      try {
        final json = (model.toJson() as Map<String, dynamic>?) ?? {};
        meDisplay = (json['name'] as String?) ??
            (json['email'] as String?) ??
            (json['username'] as String?) ??
            model.id;
      } catch (_) {
        meDisplay = model.id;
      }
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Post'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          // post header
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header row (match home.dart style)
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'r/' + (widget.post.authorName ?? widget.post.authorId),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('• ${_timeAgo(widget.post.created)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                // title
                Text(widget.post.title,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                // body
                if (widget.post.content.isNotEmpty)
                  Text(widget.post.content, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                // vote row (up / score / down) + small meta
                Row(
                  children: [
                    InkWell(
                      onTap: () => _vote(true),
                      child: Icon(
                        Icons.arrow_upward,
                        size: 20,
                        color: _myVote == 'up' ? Colors.red : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${_upvotes - _downvotes}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _vote(false),
                      child: Icon(
                        Icons.arrow_downward,
                        size: 20,
                        color: _myVote == 'down' ? Colors.red : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(widget.post.authorName ?? widget.post.authorId,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // comments
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text('ยังไม่มีความคิดเห็น'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final c = _comments[i];
                          final isOwner = currentUserId != null && currentUserId == c.authorId;
                          return Card(
                            margin: EdgeInsets.zero,
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10.0, horizontal: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.grey.shade200,
                                    child: Text(
                                      (c.authorName ?? c.authorId)
                                          .split(' ')
                                          .where((s) => s.isNotEmpty)
                                          .map((s) => s[0])
                                          .take(2)
                                          .join()
                                          .toUpperCase(),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.black54),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                c.authorName ?? c.authorId,
                                                style: theme.textTheme.bodyMedium
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700),
                                              ),
                                            ),
                                            Text(
                                              _timeAgo(c.created),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                      color: Colors.grey,
                                                      fontSize: 12),
                                            ),
                                            if (isOwner) const SizedBox(width: 6),
                                            if (isOwner)
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                icon: Icon(Icons.more_vert, size: 20, color: Colors.grey.shade700),
                                                onPressed: () => _showCommentActions(c),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          c.content,
                                          style:
                                              theme.textTheme.bodyMedium?.copyWith(
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // input (improved UI: white rounded input, red send button)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey.shade200,
                    child: Text(
                      meDisplay
                          .split(' ')
                          .map((s) => s.isNotEmpty ? s[0] : '')
                          .take(2)
                          .join()
                          .toUpperCase(),
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                        border: Border.all(color: Colors.red.withOpacity(0.08)),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 4,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          hintText: 'เขียนความคิดเห็น...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _ctrl.text.trim().isEmpty ? null : () async {
                      await _submitComment();
                      if (mounted) setState(() {}); // update send button state
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: _ctrl.text.trim().isEmpty ? Colors.grey.shade300 : Colors.red,
                      child: Icon(Icons.send, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'ตอนนี้';
    if (diff.inHours < 1) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inDays < 1) return '${diff.inHours} ชั่วโมงที่แล้ว';
    return '${diff.inDays} วันที่แล้ว';
  }
}