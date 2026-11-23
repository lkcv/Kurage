import 'package:kurage/cache/reader_page_cache.dart';
import 'package:kurage/cache/cover_cache.dart';
import 'package:kurage/providers/error_classification.dart';
import 'package:kurage/variables.dart';

String cacheFailureMessage(Object error, String fallback) =>
    switch (classifyError(error).kind) {
      AppErrorKind.storage => '$fallback (storage access failed)',
      _ => fallback,
    };

class CacheUsageSnapshot {
  const CacheUsageSnapshot({
    required this.limitMb,
    required this.usageBytes,
    required this.coverUsageBytes,
    this.error,
  });

  final int limitMb;
  final int usageBytes;
  final int coverUsageBytes;
  final String? error;

  static Future<CacheUsageSnapshot> load() async {
    try {
      final limit = await ReaderPageCache.getLimitMb();
      final usage = await ReaderPageCache.getUsageBytes();
      final coverUsage = await CoverCacheManager.getUsageBytes();
      return CacheUsageSnapshot(
        limitMb: limit,
        usageBytes: usage,
        coverUsageBytes: coverUsage,
      );
    } catch (error) {
      logger.w('ReaderCacheSettings: could not read cache usage: $error');
      return CacheUsageSnapshot(
        limitMb: ReaderPageCache.defaultLimitMb,
        usageBytes: 0,
        coverUsageBytes: 0,
        error: cacheFailureMessage(error, 'Could not read cache usage'),
      );
    }
  }
}
