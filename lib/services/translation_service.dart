import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationService {
  TranslationService._();
  static final instance = TranslationService._();

  final _cache = <String, String>{};
  final _translators = <String, OnDeviceTranslator>{};
  final _downloadedModels = <String>{};

  bool isArabic(String text) =>
      text.runes.any((r) => r >= 0x0600 && r <= 0x06FF);

  String detectLang(String text) => isArabic(text) ? 'ar' : 'en';

  Future<String?> translate(String text, String from, String to) async {
    if (from == to || text.trim().isEmpty) return null;
    final cacheKey = '$from|$to|$text';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final srcLang =
          from == 'ar' ? TranslateLanguage.arabic : TranslateLanguage.english;
      final tgtLang =
          to == 'ar' ? TranslateLanguage.arabic : TranslateLanguage.english;

      final translatorKey = '$from→$to';
      _translators[translatorKey] ??= OnDeviceTranslator(
        sourceLanguage: srcLang,
        targetLanguage: tgtLang,
      );

      final manager = OnDeviceTranslatorModelManager();
      for (final code in [from, to]) {
        if (!_downloadedModels.contains(code)) {
          final ok = await manager.isModelDownloaded(code);
          if (!ok) await manager.downloadModel(code);
          _downloadedModels.add(code);
        }
      }

      final result =
          await _translators[translatorKey]!.translateText(text);
      _cache[cacheKey] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    for (final t in _translators.values) {
      t.close();
    }
    _translators.clear();
  }
}
