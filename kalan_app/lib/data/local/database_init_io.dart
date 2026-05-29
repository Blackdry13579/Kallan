import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Android / iOS / Windows / Linux / macOS
Future<void> initLocalDatabase() async {
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
