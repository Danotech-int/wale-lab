import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../utils/constants.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({required this.baseUrl, http.Client? client, this.tokenProvider})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  final Future<String?> Function()? tokenProvider;
  String? sessionToken;

  Uri _uri(String path) {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        !base.hasAuthority ||
        !{'http', 'https'}.contains(base.scheme)) {
      throw const ApiException(
        'The service is not configured. Please contact your administrator.',
      );
    }
    return Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/'
        '${path.replaceFirst(RegExp(r'^/+'), '')}');
  }

  Future<Map<String, String>> get _headers async {
    final token = tokenProvider == null ? sessionToken : await tokenProvider!();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path) async => _decode(
        await _client
            .get(_uri(path), headers: await _headers)
            .timeout(AppConstants.requestTimeout),
      );

  Future<dynamic> post(String path, Map<String, dynamic> body) async => _decode(
        await _client
            .post(_uri(path), headers: await _headers, body: jsonEncode(body))
            .timeout(AppConstants.requestTimeout),
      );

  Future<dynamic> put(String path, Map<String, dynamic> body) async => _decode(
        await _client
            .put(_uri(path), headers: await _headers, body: jsonEncode(body))
            .timeout(AppConstants.requestTimeout),
      );

  Future<void> uploadCv(String filename, Uint8List bytes) async {
    final extension = filename.split('.').last.toLowerCase();
    if (!{'pdf', 'doc', 'docx'}.contains(extension) ||
        bytes.isEmpty ||
        bytes.length > AppConstants.maxCvBytes) {
      throw const ApiException('Choose a PDF, DOC, or DOCX file up to 5 MB.');
    }
    final request = http.MultipartRequest('POST', _uri('/profiles/me/cv'))
      ..headers.addAll({
        ...await _headers
          ..remove('Content-Type'),
      })
      ..files
          .add(http.MultipartFile.fromBytes('cv', bytes, filename: filename));
    final response = await (() async {
      final stream = await _client.send(request);
      return http.Response.fromStream(stream);
    })()
        .timeout(AppConstants.requestTimeout);
    _decode(response);
  }

  dynamic _decode(http.Response response) {
    final success = response.statusCode >= 200 && response.statusCode < 300;
    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        if (success) {
          throw const ApiException('The service returned an invalid response.');
        }
      }
    }
    if (!success) {
      throw ApiException(
        data is Map && data['message'] is String
            ? data['message'] as String
            : 'Request failed (${response.statusCode}). Please try again.',
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  void dispose() => _client.close();
}
