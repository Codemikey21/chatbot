/// Configuración de la app.
///
/// La URL de la API se elige al compilar. Por defecto apunta a la API local
/// vista desde el emulador de Android (10.0.2.2 es el computador anfitrión):
///   flutter run
/// Para el despliegue en EC2:
///   flutter run --dart-define=API_URL=https://chatbot-unab-demo.duckdns.org/api/v1
class Config {
  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8080/api/v1',
  );

  /// El chat espera la respuesta del agente (RAG, MCP, Sheets) en n8n.
  static const tiempoChat = Duration(seconds: 100);
  static const tiempoNormal = Duration(seconds: 25);
  static const maxCaracteresMensaje = 1500;
}
