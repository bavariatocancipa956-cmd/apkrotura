import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiWhatsapp {
  // IP y Puerto de tu microservicio en el servidor VPS
  static const String _baseUrl = 'http://82.39.109.211:3001/api/whatsapp';

  /// 🚀 Método universal: Consulta la tabla de cualquier esquema y envía la alerta al grupo (con o sin foto)
  static Future<bool> notificarEsquema({
    required String esquema,
    required String tablaId,
    required String campoId,
    required String mensaje,
    String? urlImagen, // 👈 Se agrega la propiedad opcional para la imagen
  }) async {
    final url = Uri.parse('$_baseUrl/notificar-esquema');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'esquema': esquema,
          'tabla_id': tablaId,
          'campo_id': campoId,
          'mensaje': mensaje,
          'url_imagen': urlImagen ?? '', // 👈 Se envía al servidor Node.js
        }),
      );

      if (response.statusCode == 200) {
        print('✅ [WhatsApp] Alerta enviada con éxito al grupo de [$esquema]');
        return true;
      } else {
        print('⚠️ [WhatsApp] Error del servidor: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ [WhatsApp] Error de conexión: $e');
      return false;
    }
  }

  // ------------------------------------------------------------------
  // 💡 ATAJOS DIRECTOS PARA CADA MÓDULO DE LA APP
  // ------------------------------------------------------------------

  /// Enviar alerta al grupo de Roturas (con opción de foto)
  static Future<bool> notificarRotura({
    required String mensaje,
    String? urlImagen,
  }) {
    return notificarEsquema(
      esquema: 'roturas',
      tablaId: 'rotura_id_whapsap',
      campoId: 'idgrupos',
      mensaje: mensaje,
      urlImagen: urlImagen,
    );
  }

  /// Enviar alerta al grupo de People / RRHH
  static Future<bool> notificarPeople({
    required String mensaje,
    String? urlImagen,
  }) {
    return notificarEsquema(
      esquema: 'people',
      tablaId: 'people_id_whatsapp',
      campoId: 'idgrupos',
      mensaje: mensaje,
      urlImagen: urlImagen,
    );
  }
}