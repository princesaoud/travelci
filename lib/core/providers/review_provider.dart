import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travelci/core/models/review.dart';
import 'package:travelci/core/services/review_service.dart';

class ReviewNotifier extends Notifier<Map<String, List<Review>>> {
  @override
  Map<String, List<Review>> build() => {};

  Future<void> loadReviews(String propertyId) async {
    if (state.containsKey(propertyId)) return;
    try {
      final reviews = await reviewApiService.getReviews(propertyId);
      state = {...state, propertyId: reviews};
    } catch (_) {
      state = {...state, propertyId: []};
    }
  }

  Future<void> refreshReviews(String propertyId) async {
    try {
      final reviews = await reviewApiService.getReviews(propertyId);
      state = {...state, propertyId: reviews};
    } catch (_) {}
  }

  Future<void> addReview({
    required String propertyId,
    required double rating,
    required String comment,
  }) async {
    final review = await reviewApiService.createReview(
      propertyId: propertyId,
      rating: rating,
      comment: comment,
    );
    final updated = [review, ...state[propertyId] ?? []];
    state = {...state, propertyId: updated};
  }

  Future<void> deleteReview(String reviewId, String propertyId) async {
    await reviewApiService.deleteReview(reviewId);
    final updated = (state[propertyId] ?? [])
        .where((r) => r.id != reviewId)
        .toList();
    state = {...state, propertyId: updated};
  }

  List<Review> getReviews(String propertyId) =>
      state[propertyId] ?? [];

  double getAverageRating(String propertyId) {
    final reviews = state[propertyId] ?? [];
    if (reviews.isEmpty) return 0;
    return reviews.map((r) => r.rating).reduce((a, b) => a + b) /
        reviews.length;
  }

  bool hasUserReviewed(String propertyId, String userId) =>
      (state[propertyId] ?? []).any((r) => r.userId == userId);
}

final reviewProvider =
    NotifierProvider<ReviewNotifier, Map<String, List<Review>>>(
  ReviewNotifier.new,
);
