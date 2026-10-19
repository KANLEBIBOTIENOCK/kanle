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

  /// Modèle Gemini haute vitesse optimisé pour les réponses JSON structurées instantanées
  static const String geminiModel = 'gemini-3.5-flash-lite';

  /// Modèles de secours en cas de pic de charge (503 / 429) sur le modèle principal
  static const List<String> fallbackModels = [
    'gemini-flash-lite-latest',
    'gemini-3.8-flash',
    'gemini-flash-latest',
  ];

  /// Indique si une clé a été renseignée
  static bool get hasKey => geminiApiKey.trim().isNotEmpty;
}
