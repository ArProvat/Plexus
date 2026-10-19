import 'package:flutter/services.dart';

class NativeBridge {
  static const _channel = MethodChannel('com.arprovat.pocketsearch/native');

  static set onSearch(void Function()? callback) {
    _channel.setMethodCallHandler(callback == null
        ? null
        : (call) async {
            if (call.method == 'openQuickSearch') callback();
          });
  }

  static Future<bool> consumeSearchLaunch() async {
    try {
      return await _channel.invokeMethod<bool>('consumeSearchLaunch') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<Map<Object?, Object?>> initializeEmbedding() async =>
      await _channel.invokeMapMethod<Object?, Object?>('initializeEmbedding') ??
      {};

  static Future<List<double>> embedQuery(String text) async =>
      (await _channel.invokeListMethod<num>('embedQuery', text))!
          .map((v) => v.toDouble())
          .toList();

  static Future<List<List<double>>> embedDocuments(List<String> texts) async =>
      (await _channel.invokeListMethod<Object?>('embedDocuments', texts))!
          .map((v) => (v as List).map((x) => (x as num).toDouble()).toList())
          .toList();

  static Future<List<Map<String, Object?>>> pickFiles() async =>
      _records(await _channel.invokeListMethod<Object?>('pickFiles'));

  static Future<Map<String, Object?>?> pickFolder() async {
    final value = await _channel.invokeMapMethod<String, Object?>('pickFolder');
    return value == null ? null : Map<String, Object?>.from(value);
  }

  static Future<List<Map<String, Object?>>> listFolder(String uri) async =>
      _records(await _channel.invokeListMethod<Object?>('listFolder', uri));

  static Future<String> readText(String uri) async =>
      await _channel.invokeMethod<String>('readText', uri) ?? '';

  static Future<int> pdfPageCount(String uri) async =>
      await _channel.invokeMethod<int>('pdfPageCount', uri) ?? 0;

  static Future<String> extractPdfPage(String uri, int page) async =>
      await _channel
          .invokeMethod<String>('extractPdfPage', {'uri': uri, 'page': page}) ??
      '';

  static Future<void> closePdf() async =>
      _channel.invokeMethod<void>('closePdf');

  static Future<List<Map<String, Object?>>> extractOffice(
          String uri, String name) async =>
      _records(await _channel.invokeListMethod<Object?>(
          'extractOffice', {'uri': uri, 'name': name}));

  static Future<void> openSource(String uri) async =>
      _channel.invokeMethod<void>('openSource', uri);

  static Future<Map<Object?, Object?>> modelStatus() async =>
      await _channel.invokeMapMethod<Object?, Object?>('modelStatus') ?? {};

  static Future<void> downloadModel() async =>
      _channel.invokeMethod<void>('downloadModel');

  static List<Map<String, Object?>> _records(List<Object?>? values) =>
      (values ?? []).map((v) => Map<String, Object?>.from(v as Map)).toList();
}
