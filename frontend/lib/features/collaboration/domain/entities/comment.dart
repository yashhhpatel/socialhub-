/// A comment on a design (GET/POST /content/assets/:id/comments).
class Comment {
  const Comment({
    required this.id,
    required this.body,
    required this.authorEmail,
    required this.createdAt,
  });

  final String id;
  final String body;
  final String authorEmail;
  final DateTime createdAt;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as String,
        body: json['body'] as String,
        authorEmail: json['authorEmail'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
