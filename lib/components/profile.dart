import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '/pocketbase_client.dart';
import '/auth/login.dart';
import '/models/models.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _user;
  List<Post> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final model = pb.authStore.model;
      if (model == null) {
        // not authenticated -> go to login
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
        }
        return;
      }

      // convert user model to map safely
      Map<String, dynamic> userMap;
      try {
        final m = model.toJson();
        userMap = m is Map<String, dynamic> ? m : <String, dynamic>{};
      } catch (_) {
        userMap = <String, dynamic>{};
      }
      setState(() => _user = userMap);

      final userId = userMap['id'] ?? model.id ?? '';
      if (userId.isEmpty) {
        setState(() {
          _error = 'ไม่พบข้อมูลผู้ใช้';
          _posts = [];
        });
        return;
      }

      // fetch posts by this user
      final recs = await pb.collection('post').getFullList(
        filter: 'authorId = "$userId"',
        sort: '-created',
        expand: 'authorId',
      );

      // convert records to Post models with comment counts
      final futures = recs.map<Future<Post?>>((r) async {
        try {
          final data = Map<String, dynamic>.from(r.data);
          
          // Add expand data with author information
          if (r.expand case {'authorId': List<dynamic> authorRecords} when authorRecords.isNotEmpty) {
            final authorRecord = authorRecords.first as RecordModel;
            data['expand'] = {
              'authorId': authorRecord.data,
            };
          }
          
          // Add comment count
          final commentCount = await pb.collection('comment').getList(
            filter: 'postId = "${r.id}"',
            page: 1,
            perPage: 1,
          );
          data['commentCount'] = commentCount.totalItems;

          return Post.fromJson(data);
        } catch (e) {
          print('Error parsing post: $e');
        }
        return null;
      });
      
      // Wait for all futures to complete and filter out nulls
      final list = (await Future.wait(futures)).whereType<Post>().toList();

      setState(() {
        _posts = list;
      });
    } catch (e) {
      setState(() {
        _error = 'เกิดข้อผิดพลาดในการดึงข้อมูล';
        _posts = [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _displayName() {
    if (_user == null) return 'ผู้ใช้';
    return _user!['username'] ?? _user!['name'] ?? _user!['email'] ?? 'ผู้ใช้';
  }

  String _initials() {
    final name = _displayName();
    final parts = name.split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'ตอนนี้';
    if (diff.inHours < 1) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inDays < 1) return '${diff.inHours} ชั่วโมงที่แล้ว';
    return '${diff.inDays} วันที่แล้ว';
  }

  // Show edit dialog using a dedicated stateful dialog widget to manage controllers safely
  Future<void> _showEditDialog(Post post) async {
    await showDialog<void>(
      context: context,
      builder: (context) => EditPostDialog(
        post: post,
        onSaved: () {
          // refresh posts after successful save
          _loadProfile();
        },
      ),
    );
  }
  

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(primary: Colors.red),
      textTheme: theme.textTheme.apply(fontFamily: 'NotoSansThai'),
      primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'NotoSansThai'),
    );

    return Theme(
      data: localTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('โปรไฟล์'),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: localTheme.colorScheme.primary,
          elevation: 2,
        ),
        body: RefreshIndicator(
          onRefresh: _loadProfile,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      children: [
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: Colors.red.shade100,
                                  child: Text(_initials(), style: TextStyle(color: Colors.red.shade700, fontSize: 20, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_displayName(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      Text(_user?['email'] ?? '', style: theme.textTheme.bodySmall),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Chip(
                                            backgroundColor: Colors.red.shade50,
                                            label: Text('${_posts.length} โพสต์', style: TextStyle(color: Colors.red.shade700)),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            child: const Text('แก้ไขโปรไฟล์'),
                                          )
                                        ],
                                      )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('โพสต์ของฉัน', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        if (_posts.isEmpty)
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  const Icon(Icons.article_outlined, size: 48, color: Colors.grey),
                                  const SizedBox(height: 8),
                                  Text('ยังไม่มีโพสต์', style: theme.textTheme.bodyMedium),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._posts.map((p) {
                            final title = p.title;
                            final content = p.content;
                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 1,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(_timeAgo(p.created), 
                                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)
                                        ),
                                        const SizedBox(width: 12),
                                        InkWell(
                                          onTap: () => _showEditDialog(p),
                                          child: Icon(Icons.edit, size: 16, color: Colors.grey.shade600),
                                        ),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            Icon(Icons.thumb_up_outlined, size: 16, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text('${p.upvotes - p.downvotes}',
                                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(Icons.comment_outlined, size: 16, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text('${p.commentCount}',
                                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      title.isEmpty ? '(ไม่มีหัวข้อ)' : title,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (content.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        content,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          height: 1.5,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList()
                      ],
                    ),
        ),
      ),
    );
  }
}

// A dedicated dialog widget that owns its TextEditingControllers and disposes them in dispose().
class EditPostDialog extends StatefulWidget {
  final Post post;
  final VoidCallback? onSaved;
  const EditPostDialog({Key? key, required this.post, this.onSaved}) : super(key: key);

  @override
  State<EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<EditPostDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _contentController = TextEditingController(text: widget.post.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final title = _titleController.text.trim();
      final content = _contentController.text.trim();
      if (title.isEmpty && content.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาใส่หัวข้อหรือเนื้อหา')));
        return;
      }

      await pb.collection('post').update(
        widget.post.id,
        body: {'title': title, 'content': content},
      );

      widget.onSaved?.call();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('แก้ไขโพสต์สำเร็จ'), behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('แก้ไขโพสต์', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(), tooltip: 'ปิด')
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'หัวข้อ', hintText: 'ใส่หัวข้อโพสต์', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50),
                maxLines: 1,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                decoration: InputDecoration(labelText: 'เนื้อหา', hintText: 'ใส่เนื้อหาโพสต์', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50),
                maxLines: 8,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('ยกเลิก'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                          : const Text('บันทึก'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}