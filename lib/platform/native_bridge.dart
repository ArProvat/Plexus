import 'package:flutter/services.dart';

class NativeBridge {
  static const _channel = MethodChannel('com.arprovat.pocketsearch/native');

  static set onSearch(void Function()? callback) {
    _channel.setMethodCallHandler(callback == null ? null : (call) async {
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
      await _channel.invokeMapMethod<Object?, Object?>('initializeEmbedding') ?? {};

  static Future<List<double>> embedQuery(String text) async =>
      (await _channel.invokeListMethod<num>('embedQuery', text))!
          .map((v) => v.toDouble()).toList();

  static Future<List<List<double>>> embedDocuments(List<String> texts) async =>
      (await _channel.invokeListMethod<Object?>('embedDocuments', texts))!
          .map((v) => (v as List).map((x) => (x as num).toDouble()).toList())
          .toList();
}
