import 'package:flutter/services.dart';

class DocumentFileService {
  static const MethodChannel _channel = MethodChannel('reading.documents');

  Future<bool> exportText({
    required String fileName,
    required String mimeType,
    required String content,
  }) async {
    return await _channel.invokeMethod<bool>('exportText', {
          'fileName': fileName,
          'mimeType': mimeType,
          'content': content,
        }) ??
        false;
  }

  Future<String?> importText({required List<String> mimeTypes}) async {
    return _channel.invokeMethod<String>('importText', {
      'mimeTypes': mimeTypes,
    });
  }
}
