import 'dart:convert';

class Review {
  final String id;
  final String propertyId;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.propertyId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'propertyId': propertyId,
        'userId': userId,
        'userName': userName,
        'rating': rating,
        'comment': comment,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        propertyId: json['property_id'] as String? ?? json['propertyId'] as String,
        userId: json['user_id'] as String? ?? json['userId'] as String,
        userName: json['user_name'] as String? ?? json['userName'] as String,
        rating: (json['rating'] as num).toDouble(),
        comment: json['comment'] as String,
        createdAt: DateTime.parse(
          json['created_at'] as String? ?? json['createdAt'] as String,
        ),
      );

  static List<Review> listFromJson(String raw) {
    final list = jsonDecode(raw) as List;
    return list.map((e) => Review.fromJson(e as Map<String, dynamic>)).toList();
  }
}
