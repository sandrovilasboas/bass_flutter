import 'dart:ffi';
import 'dart:io';
import 'bass_bindings.dart';

class BassLoader {
  static BASS? _instance;

  static BASS get instance {
    if (_instance != null) return _instance!;

    final DynamicLibrary lib;

    if (Platform.isMacOS) {
      lib = DynamicLibrary.open('libbass.dylib');
    } else if (Platform.isWindows) {
      lib = DynamicLibrary.open('bass.dll');
    } else {
      throw UnsupportedError('Platform not supported');
    }

    _instance = BASS(lib);
    return _instance!;
  }
}
