import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Chrome / Edge / Safari (Flutter web)
Future<void> initLocalDatabase() async {
  databaseFactory = databaseFactoryFfiWeb;
}
