import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';

class TranslationService {
  TranslationService._();
  static final instance = TranslationService._();

  final _cache = <String, String>{};
  final _translators = <String, OnDeviceTranslator>{};
  final _downloadedModels = <String>{};
  final _languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.4);

  // Normalize 'zh-Hans', 'zh-Hant', 'pt-BR' → 'zh', 'pt', etc.
  String _base(String code) => code.split('-').first.toLowerCase();

  // Strip lone surrogates / null bytes that crash JNI NewStringUTF
  String _sanitize(String text) {
    final buf = StringBuffer();
    for (final rune in text.runes) {
      if (rune != 0 && !(rune >= 0xD800 && rune <= 0xDFFF)) {
        buf.writeCharCode(rune);
      }
    }
    return buf.toString();
  }

  // Detect language of any text using ML Kit
  Future<String> identifyLanguage(String text) async {
    if (text.trim().isEmpty) return 'en';
    try {
      final result = await _languageIdentifier.identifyLanguage(_sanitize(text));
      if (result == 'und' || result.isEmpty) return 'en';
      return _base(result);
    } catch (_) {
      return 'en';
    }
  }

  Future<String?> translate(String text, String from, String to) async {
    final fromBase = _base(from);
    final toBase = _base(to);
    if (fromBase == toBase || text.trim().isEmpty) return null;

    final safe = _sanitize(text);
    final cacheKey = '$fromBase|$toBase|$safe';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];

    try {
      final srcLang = TranslateLanguage.values.firstWhere(
        (l) => l.bcpCode == fromBase,
        orElse: () => TranslateLanguage.english,
      );
      final tgtLang = TranslateLanguage.values.firstWhere(
        (l) => l.bcpCode == toBase,
        orElse: () => TranslateLanguage.english,
      );

      // If neither language is supported, bail out
      if (srcLang == tgtLang) return null;

      final translatorKey = '$fromBase→$toBase';
      _translators[translatorKey] ??= OnDeviceTranslator(
        sourceLanguage: srcLang,
        targetLanguage: tgtLang,
      );

      final manager = OnDeviceTranslatorModelManager();
      for (final code in [fromBase, toBase]) {
        if (!_downloadedModels.contains(code)) {
          final ok = await manager.isModelDownloaded(code);
          if (!ok) await manager.downloadModel(code);
          _downloadedModels.add(code);
        }
      }

      final result = await _translators[translatorKey]!.translateText(safe);
      _cache[cacheKey] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _languageIdentifier.close();
    for (final t in _translators.values) {
      t.close();
    }
    _translators.clear();
  }
}
