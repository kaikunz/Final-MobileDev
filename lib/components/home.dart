import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '/pocketbase_client.dart';
import '/models/models.dart';
import '/auth/login.dart';
import '/components/post_detail.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  String? _error;
  List<Post> _posts = [];
  final Map<String, String?> _avatars = {};
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Fetch posts with comment counts
      final recs = await pb.collection('post').getFullList(
        expand: 'authorId',
        sort: '-created', // Sort by creation date, newest first
      );
      
      // Get comment counts for all posts
      final commentCounts = await Future.wait(
        recs.map((post) => pb.collection('comment').getList(
          filter: 'postId = "${post.id}"',
          page: 1,
          perPage: 1,
        ).then((result) => {post.id: result.totalItems})),
      );
      final recsList = recs.toList();
      final takeCount = recsList.length > 50 ? 50 : recsList.length;
      final selected = recsList.take(takeCount).toList();

      _avatars.clear();
      for (final r in selected) {
        try {
          
          if (r.expand case {'authorId': List<dynamic> authorRecords} when authorRecords.isNotEmpty) {
            final authorRecord = authorRecords.first as RecordModel;
            final authorData = authorRecord.data;
            if (authorData case {'avatar': String avatar} when avatar.isNotEmpty) {
              final authorId = authorRecord.id;
              final avatarUrl =
                  'http://127.0.0.1:8090/api/files/_pb_users_auth_/$authorId/$avatar';
              _avatars[r.id] = avatarUrl;
              continue;
            }
          }
        } catch (e) {
          print('Error processing avatar: $e');
        }
        _avatars[r.id] = null;
      }

      final futures = selected.map<Future<Post?>>((r) async {
            try {
              final data = Map<String, dynamic>.from(r.data);
              
              // Add expand data with author information
              final authorRecords = r.expand['authorId'] as List<dynamic>?;
              if (authorRecords != null && authorRecords.isNotEmpty) {
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
      final list = (await Future.wait(futures)).whereType<Post>().toList();      setState(() {
        _posts = list;
      });
    } catch (e) {
      setState(() {
        _error = 'เกิดข้อผิดพลาดในการดึงโพสต์';
        _posts = [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _showCreatePostDialog() async {
    // Clear previous text
    _titleController.clear();
    _contentController.clear();
    bool isLoading = false;

    final userModel = pb.authStore.model;
    if (userModel == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'สร้างโพสต์ใหม่',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Title input
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: _titleController,
                        style: const TextStyle(fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: 'หัวข้อโพสต์...',
                          border: InputBorder.none,
                          counterText: '',
                        ),
                        maxLength: 100,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Content input
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: _contentController,
                        maxLines: 8,
                        style: const TextStyle(fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: 'เนื้อหาโพสต์...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Submit button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final title = _titleController.text.trim();
                            final content = _contentController.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('กรุณาใส่หัวข้อโพสต์')),
                              );
                              return;
                            }

                            setState(() => isLoading = true);
                            try {
                              await pb.collection('post').create(body: {
                                'title': title,
                                'content': content,
                                'authorId': userModel.id,
                                'upvotes': 0,
                                'downvotes': 0,
                              });
                              if (context.mounted) {
                                Navigator.pop(context);
                                _fetchPosts();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ไม่สามารถสร้างโพสต์ได้')),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => isLoading = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'โพสต์',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
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

  Future<void> _vote(Post p, bool up) async {
    // require loginR
    final userModel = pb.authStore.model;
    if (userModel == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }
    final userId = userModel.id;

    // find index of the post in the local list
    final idx = _posts.indexWhere((x) => x.id == p.id);
    if (idx == -1) return;

    try {
      // look for existing vote by this user on this post
      final existing = await pb.collection('vote').getFullList(
        filter: 'userId = "$userId" && postId = "${p.id}"',
      );

      // helper to build a new Post with updated counts
      Post withCounts(Post src, int upvotes, int downvotes) {
        return Post(
          id: src.id,
          title: src.title,
          content: src.content,
          authorId: src.authorId,
          upvotes: upvotes,
          downvotes: downvotes,
          created: src.created,
          authorName: src.authorName,
          commentCount: src.commentCount,
        );
      }

      // current counts
      var curUp = p.upvotes;
      var curDown = p.downvotes;

      if (existing.isEmpty) {
        // create new vote
        final body = {'userId': userId, 'postId': p.id, 'type': up ? 'up' : 'down'};
        await pb.collection('vote').create(body: body);

        if (up) curUp = curUp + 1;
        else curDown = curDown + 1;

        setState(() {
          _posts[idx] = withCounts(p, curUp, curDown);
        });
      } else {
        final rec = existing.first;
        final json = rec.toJson();

        // determine current vote type (support legacy numeric 'value' or string 'type')
        String curType = '';
        if (json['type'] is String) {
          curType = json['type'] as String;
        } else if (json['value'] != null) {
          final v = (json['value'] is int) ? json['value'] as int : int.tryParse('${json['value']}') ?? 0;
          curType = v > 0 ? 'up' : 'down';
        }

        final wanted = up ? 'up' : 'down';

        if (curType == wanted) {
          // toggle off -> delete vote
          await pb.collection('vote').delete(rec.id);
          if (up) curUp = (curUp - 1).clamp(0, 1 << 30);
          else curDown = (curDown - 1).clamp(0, 1 << 30);

          setState(() {
            _posts[idx] = withCounts(p, curUp, curDown);
          });
        } else {
          // switch vote -> update record
          final updateBody = json.containsKey('type') ? {'type': wanted} : {'value': (up ? 1 : -1)};
          await pb.collection('vote').update(rec.id, body: updateBody);

          if (up) {
            curUp = curUp + 1;
            curDown = (curDown - 1).clamp(0, 1 << 30);
          } else {
            curDown = curDown + 1;
            curUp = (curUp - 1).clamp(0, 1 << 30);
          }

          setState(() {
            _posts[idx] = withCounts(p, curUp, curDown);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ไม่สามารถลงคะแนนได้')));
      // refresh to ensure consistency
      setState(() {
        _fetchPosts();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Chicken Forum'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePostDialog,
        backgroundColor: Colors.red,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPosts,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final p = _posts[index];
                      return InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PostDetail(post: p)),
                        ),
                        child: Container(
                         margin: const EdgeInsets.only(bottom: 12),
                         decoration: BoxDecoration(
                           color: Colors.white,
                           borderRadius: BorderRadius.circular(10),
                           border: Border.all(color: Colors.grey.shade300),
                         ),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             // Header row: subreddit + author + time
                             Padding(
                               padding: const EdgeInsets.symmetric(
                                   horizontal: 12, vertical: 10),
                               child: Row(
                                 children: [
                                   CircleAvatar(
                                     radius: 12,
                                     backgroundImage: _avatars[p.id] != null
                                         ? NetworkImage(_avatars[p.id]!)
                                         : null,
                                     backgroundColor: Colors.grey.shade100,
                                     child: _avatars[p.id] == null
                                         ? const Icon(Icons.person,
                                             size: 14, color: Colors.grey)
                                         : null,
                                   ),
                                   const SizedBox(width: 8),
                                   Text(
                                     p.authorName ?? 'Anonymous',
                                     style: theme.textTheme.bodySmall?.copyWith(
                                       fontWeight: FontWeight.w600,
                                       color: Colors.grey.shade700,
                                     ),
                                   ),
                                   const SizedBox(width: 8),
                                   Text('• ${_timeAgo(p.created)}',
                                       style: theme.textTheme.bodySmall
                                           ?.copyWith(color: Colors.grey)),
                                 ],
                               ),
                             ),

                            // Title
                            Padding(
                               padding:
                                   const EdgeInsets.symmetric(horizontal: 12),
                               child: Text(
                                 p.title,
                                 style: theme.textTheme.titleMedium?.copyWith(
                                     fontWeight: FontWeight.w800, fontSize: 17),
                               ),
                             ),

                            // Body
                            if (p.content.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Text(
                                  p.content,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),

                            const SizedBox(height: 6),

                            // Action row (vote + comment + share)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  // separate up / score / down so each has its own onTap
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () => _vote(p, true),
                                        child: const Icon(Icons.arrow_upward,
                                            size: 18, color: Colors.grey),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${p.upvotes - p.downvotes}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _vote(p, false),
                                        child: const Icon(Icons.arrow_downward,
                                            size: 18, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Row(
                                    children: [
                                      const Icon(Icons.mode_comment_outlined,
                                          size: 18, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text('${p.commentCount}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Row(
                                    children: [
                                      const Icon(Icons.share_outlined,
                                          size: 18, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text('Share',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                      );
                    },
                  ),
      ),
    );
  }
}
