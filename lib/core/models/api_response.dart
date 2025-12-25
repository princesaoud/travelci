/// API Response Model
/// 
/// Generic model for API responses
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final PaginationInfo? pagination;
  final ApiError? error;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.pagination,
    this.error,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? dataParser,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      data: json['data'] != null && dataParser != null
          ? dataParser(json['data'])
          : json['data'] as T?,
      message: json['message'] as String?,
      pagination: json['pagination'] != null
          ? PaginationInfo.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
      error: json['error'] != null
          ? ApiError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data,
      'message': message,
      'pagination': pagination?.toJson(),
      'error': error?.toJson(),
    };
  }
}

/// Pagination Information
class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final int pages;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
      pages: json['pages'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'limit': limit,
      'total': total,
      'pages': pages,
    };
  }

  bool get hasNextPage => page < pages;
  bool get hasPreviousPage => page > 1;
}

/// API Error Model
class ApiError {
  final String message;
  final String? code;
  final int? statusCode;

  ApiError({
    required this.message,
    this.code,
    this.statusCode,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      message: json['message'] as String? ?? 'Une erreur s\'est produite',
      code: json['code'] as String?,
      statusCode: json['statusCode'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'code': code,
      'statusCode': statusCode,
    };
  }
}

