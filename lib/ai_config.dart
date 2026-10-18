/// Configuration centrale pour l'Assistant IA et Google Gemini.
/// Vous pouvez renseigner votre clé API directement ci-dessous dans le code.
class AiConfig {
  /// Clé API Google Gemini (peut être passée par --dart-define=GEMINI_API_KEY=... ou configurée dans l'app)
  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Modèle Gemini recommandé (supporte v1beta et v1)
  static const String geminiModel = 'gemini-flash-latest';

  /// Indique si une clé a été renseignée
  static bool get hasKey => geminiApiKey.trim().isNotEmpty;
}
