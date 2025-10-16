class Post {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final int upvotes;
  final int downvotes;
  final DateTime created;
  final String? authorName;
  final int commentCount;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.upvotes,
    required this.downvotes,
    required this.created,
    this.authorName,
    this.commentCount = 0,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'],
        title: json['title'] ?? '',
        content: json['content'] ?? '',
        authorId: json['authorId'] ?? '',
        upvotes: json['upvotes'] ?? 0,
        downvotes: json['downvotes'] ?? 0,
        created: DateTime.parse(json['created']),
        authorName: json['expand'] != null &&
                json['expand']['authorId'] != null &&
                (json['expand']['authorId'] as Map<String, dynamic>)['name'] != null
            ? (json['expand']['authorId'] as Map<String, dynamic>)['name']
            : null,
        commentCount: json['commentCount'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "content": content,
        "authorId": authorId,
        "upvotes": upvotes,
        "downvotes": downvotes,
        "created": created.toIso8601String(),
      };
}

class Comment {
  final String id;
  final String postId;
  final String authorId;
  final String content;
  final DateTime created;
  final String? authorName;

  Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    required this.created,
    this.authorName,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'],
        postId: json['post'] ?? '',
        authorId: json['author'] ?? '',
        content: json['content'] ?? '',
        created: DateTime.parse(json['created']),
        authorName: json['expand'] != null &&
                json['expand']['author'] != null &&
                json['expand']['author']['name'] != null
            ? json['expand']['author']['name']
            : null,
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "post": postId,
        "author": authorId,
        "content": content,
        "created": created.toIso8601String(),
      };
}

class User {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        avatarUrl: json['avatar'] != null
            ? "http://127.0.0.1:8090/api/files/_pb_users_auth_/${json['id']}/${json['avatar']}"
            : null,
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "email": email,
        "avatar": avatarUrl,
      };
}

class Vote {
  final String id;
  final String postId;
  final String userId;
  final String type;
  final DateTime created;

  Vote({
    required this.id,
    required this.postId,
    required this.userId,
    required this.type,
    required this.created,
  });

  factory Vote.fromJson(Map<String, dynamic> json) => Vote(
        id: json['id'],
        postId: json['post'] ?? '',
        userId: json['user'] ?? '',
        type: json['type'] ?? '',
        created: DateTime.parse(json['created']),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "post": postId,
        "user": userId,
        "type": type,
        "created": created.toIso8601String(),
      };
}
