import 'package:travelci/core/models/review.dart';
import 'package:travelci/core/services/api_service.dart';
import 'package:travelci/core/utils/api_config.dart';

class ReviewService extends ApiService {
  /// Returns all reviews for a property.
  Future<List<Review>> getReviews(String propertyId) async {
    final response = await get<Map<String, dynamic>>(
      ApiConfig.reviewsForPropertyEndpoint(propertyId),
      parser: (data) => data as Map<String, dynamic>,
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    final list = data['reviews'] as List<dynamic>? ?? [];
    return list
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates a review for a property (authenticated client only).
  Future<Review> createReview({
    required String propertyId,
    required double rating,
    required String comment,
  }) async {
    final response = await post<Map<String, dynamic>>(
      ApiConfig.reviewsForPropertyEndpoint(propertyId),
      data: {'rating': rating, 'comment': comment},
      parser: (data) => data as Map<String, dynamic>,
    );
    final data = response['data'] as Map<String, dynamic>? ?? {};
    return Review.fromJson(data['review'] as Map<String, dynamic>);
  }

  /// Deletes a review by ID.
  Future<void> deleteReview(String reviewId) async {
    await delete<void>(
      ApiConfig.reviewEndpoint(reviewId),
      parser: (_) {},
    );
  }
}

final reviewApiService = ReviewService();
