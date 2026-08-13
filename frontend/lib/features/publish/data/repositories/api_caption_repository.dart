import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/repositories/caption_repository.dart';

class ApiCaptionRepository implements CaptionRepository {
  ApiCaptionRepository(this._dio);

  final Dio _dio;

  @override
  Future<String> generate({required String assetId, String? tone}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/ai/caption',
      data: {
        'assetId': assetId,
        // Omitted entirely rather than sent as null: the DTO marks tone
        // @IsOptional, and ValidationPipe runs with forbidNonWhitelisted,
        // so an explicit null is a 400 where an absent key is fine.
        if (tone != null) 'tone': tone,
      },
    );
    return response.data!['caption'] as String;
  }
}

final captionRepositoryProvider = Provider<CaptionRepository>((ref) {
  return ApiCaptionRepository(ref.watch(apiClientProvider));
});
