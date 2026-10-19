import 'dart:convert';

/// Configuration centrale pour l'Assistant IA et Google Gemini.
class AiConfig {
  /// Clé API Google Gemini intégrée directement au code
  static String get geminiApiKey {
    const fromEnv = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    if (fromEnv.trim().isNotEmpty) return fromEnv.trim();
    try {
      const encoded =
          'QVEuQWI4Uk42SmRaX2dNaUNyNjhiVldVbzZIZUNyZmFXZHVyS2xVMG9rdjhuVmlfWGNvZlE=';
      return utf8.decode(base64.decode(encoded));
    } catch (_) {
      return '';
    }
  }

  /// Modèle Gemini recommandé (supporte v1beta et v1)
  static const String geminiModel = 'gemini-flash-latest';

  /// Indique si une clé a été renseignée
  static bool get hasKey => geminiApiKey.trim().isNotEmpty;
}
