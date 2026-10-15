import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // 👈 Necesario para Uint8List
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  static const String baseUrl = 'https://plantatocancipa.site/api/v1';
  static const String database = 'db_logistica';
  static const String apiKey = 'PlantaLogistica2026*';

  static final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'x-api-key': apiKey,
  };

  // 🟢 CONSULTAR
  static Future<List<dynamic>> consultar(String esquema, String tabla) async {
    final url = Uri.parse('$baseUrl/$database/consultar/$esquema/$tabla');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      // 🛡️ REGLA INTELIGENTE DE LECTURA
      if (decoded is List) {
        return decoded;
      } else if (decoded is Map<String, dynamic> && decoded['data'] != null) {
        return decoded['data'] is List ? decoded['data'] : [decoded['data']];
      } else {
        return []; // Retorna lista vacía si no encuentra un formato reconocible
      }
    } else {
      throw Exception('Error de API: ${response.body}');
    }
  }

  // 🔵 INSERTAR
  static Future<Map<String, dynamic>> insertar(String esquema, String tabla, Map<String, dynamic> datos) async {
    final url = Uri.parse('$baseUrl/$database/insertar/$esquema/$tabla');
    final response = await http.post(url, headers: _headers, body: jsonEncode(datos));
    if (response.statusCode == 201 || response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      // 🛡️ REGLA INTELIGENTE PARA INSERTAR
      if (decoded is Map<String, dynamic>) {
        return decoded['data'] ?? decoded; // Devuelve 'data' si existe, si no, todo el objeto
      } else if (decoded is List && decoded.isNotEmpty) {
        return decoded.first; // Si la respuesta es una lista, devuelve el primer elemento (el registro insertado)
      } else {
        return {}; // Retorno por defecto si la respuesta es extraña
      }
    } else {
      throw Exception('Error guardando datos: ${response.body}');
    }
  }

  // 🟡 ACTUALIZAR
  static Future<Map<String, dynamic>> actualizar(
      String esquema,
      String tabla,
      Map<String, dynamic> datos,
      String idColumna,
      dynamic idValor,
      ) async {
    final url = Uri.parse('$baseUrl/$database/actualizar/$esquema/$tabla/$idColumna/$idValor');

    final response = await http.put(
      url,
      headers: _headers,
      body: jsonEncode(datos),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);

      // 🛡️ REGLA INTELIGENTE PARA ACTUALIZAR
      if (body is Map<String, dynamic>) {
        return body['data'] ?? body;
      } else if (body is List && body.isNotEmpty) {
        return body.first;
      } else {
        return {};
      }
    } else {
      throw Exception('Error al actualizar datos: ${response.body}');
    }
  }

  // 🔴 ELIMINAR
  static Future<bool> eliminar(String esquema, String tabla, String idColumna, dynamic idValor, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('$baseUrl/$database/eliminar/$esquema/$tabla/$idColumna/$idValor');

    final response = await http.delete(
      url,
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Error al eliminar: ${response.body}');
    }
  }

  // 📸 SUBIR FOTO DESDE ARCHIVO (File)
  static Future<String?> subirFoto(String nombreCampo, File archivo) async {
    final url = Uri.parse('$baseUrl/archivos/subir');
    var request = http.MultipartRequest('POST', url);
    request.headers.addAll({'x-api-key': apiKey});

    String ext = '.jpg';
    String tipoMime = 'jpeg';
    if (archivo.path.toLowerCase().endsWith('.png')) {
      ext = '.png';
      tipoMime = 'png';
    }

    final bytes = await archivo.readAsBytes();

    request.files.add(http.MultipartFile.fromBytes(
      nombreCampo,
      bytes,
      filename: '${nombreCampo}_${DateTime.now().millisecondsSinceEpoch}$ext',
      contentType: MediaType('image', tipoMime),
    ));

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final json = jsonDecode(responseData);

    if (response.statusCode == 200 && json['exito'] == true) {
      return json['urls'][nombreCampo];
    } else {
      final mensajeError = json['error'] ?? responseData;
      throw Exception(mensajeError.toString().trim());
    }
  }

  // 📸 SUBIR FOTO DESDE BYTES (Uint8List) 👈 MÉTODO AGREGADO
  static Future<String?> subirFotoBytes(String nombreCampo, Uint8List bytes, {String ext = '.png'}) async {
    final url = Uri.parse('$baseUrl/archivos/subir');
    var request = http.MultipartRequest('POST', url);
    request.headers.addAll({'x-api-key': apiKey});

    String tipoMime = (ext.contains('jpg') || ext.contains('jpeg')) ? 'jpeg' : 'png';
    if (!ext.startsWith('.')) ext = '.$ext';

    request.files.add(http.MultipartFile.fromBytes(
      nombreCampo,
      bytes,
      filename: '${nombreCampo}_${DateTime.now().millisecondsSinceEpoch}$ext',
      contentType: MediaType('image', tipoMime),
    ));

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    final json = jsonDecode(responseData);

    if (response.statusCode == 200 && json['exito'] == true) {
      return json['urls'][nombreCampo];
    } else {
      final mensajeError = json['error'] ?? responseData;
      throw Exception(mensajeError.toString().trim());
    }
  }

  // ✉️ ENVIAR CORREO
  static Future<void> enviarCorreo({
    required String esquemaCredenciales,
    required String tablaCredenciales,
    required String para,
    required String asunto,
    required String html,
    String? adjuntoBase64,
  }) async {
    final url = Uri.parse('$baseUrl/$database/$esquemaCredenciales/$tablaCredenciales/enviar');

    final Map<String, dynamic> bodyData = {
      'para': para,
      'asunto': asunto,
      'html': html,
    };

    if (adjuntoBase64 != null) {
      bodyData['adjuntoBase64'] = adjuntoBase64;
    }

    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(bodyData),
    );

    if (response.statusCode != 200) {
      throw Exception('Fallo al enviar correo: ${response.body}');
    }
  }
}