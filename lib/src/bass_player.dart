import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:bass_flutter/src/ffi/bass_bindings.dart';
import 'package:ffi/ffi.dart';
import 'package:bass_flutter/src/ffi/bass_constants.dart';
import 'package:bass_flutter/src/ffi/bass_ffi_loader.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert' show latin1;

enum BassPlayerStatus { stopped, playing, stalled, paused, unknown }

extension on int {
  BassPlayerStatus toPlayerStatus() {
    switch (this) {
      case BassChannelStatus.STOPPED:
        return BassPlayerStatus.stopped;
      case BassChannelStatus.PLAYING:
        return BassPlayerStatus.playing;
      case BassChannelStatus.STALLED:
        return BassPlayerStatus.stalled;
      case BassChannelStatus.PAUSED:
        return BassPlayerStatus.paused;
      default:
        return BassPlayerStatus.unknown;
    }
  }
}

class LevelStereo {
  final double left;
  final double right;
  const LevelStereo(this.left, this.right);
}

class BassAudioDevice {
  final int id;
  final String name;
  const BassAudioDevice(this.id, this.name);
}

class BassPlayer {
  final int id;

  String? music;
  int _stream = 0;

  // --- NOVO: device por player + init cache
  int _deviceId = -1;
  static final Set<int> _initedDevices = {};

  final _statusController = StreamController<BassPlayerStatus>.broadcast();
  Stream<BassPlayerStatus> get statusStream => _statusController.stream;

  final _levelController = StreamController<LevelStereo>.broadcast();
  Stream<LevelStereo> get levelStream => _levelController.stream;

  BassPlayerStatus _lastStatus = BassPlayerStatus.unknown;
  Timer? _monitorTimer;
  Timer? _levelTicker;

  final Map<String, Map<int, List<double>>> _waveformCacheByPath = {};

  BassPlayer(this.id) {
    _startMonitoring();
    _startLevelTicker();
  }

  // ---------- Helpers de device ----------
  bool _ensureInitDevice(int id) {
    final bass = BassLoader.instance;
    if (_initedDevices.contains(id)) return true;

    final ok = bass.BASS_Init(id, 44100, 0, nullptr, nullptr) != 0;
    if (!ok && bass.BASS_ErrorGetCode() != 14) {
      debugPrint('BASS_Init($id) falhou: ${bass.BASS_ErrorGetCode()}');
      return false;
    }
    _initedDevices.add(id);
    return true;
  }

  T _withDevice<T>(T Function() fn, {T? onFail}) {
    final bass = BassLoader.instance;
    final prev = bass.BASS_GetDevice();
    if (_deviceId == -1) return onFail as T;
    if (bass.BASS_SetDevice(_deviceId) == 0) {
      debugPrint(
        'BASS_SetDevice($_deviceId) falhou: ${bass.BASS_ErrorGetCode()}',
      );
      return onFail as T;
    }
    try {
      return fn();
    } finally {
      bass.BASS_SetDevice(prev);
    }
  }

  // ---------- API ----------
  bool setAudioDevice(int id) {
    if (!_ensureInitDevice(id)) return false;
    _deviceId = id; // não fixa SetDevice global
    return true;
  }

  int getDevice() => _deviceId;

  List<BassAudioDevice> listAudioDevices() {
    final bass = BassLoader.instance;
    final devices = <BassAudioDevice>[];
    final infoPtr = calloc<BASS_DEVICEINFO>();
    for (var i = 0; bass.BASS_GetDeviceInfo(i, infoPtr) != 0; i++) {
      final info = infoPtr.ref;
      if ((info.flags & BASS_DEVICE_ENABLED) != 0) {
        final name = _readDeviceName(info.name.cast<Void>());
        devices.add(BassAudioDevice(i, name));
      }
    }
    calloc.free(infoPtr);
    return devices;
  }

<<<<<<< HEAD
  String _readAnsi(Pointer<Uint8> p) {
    final bytes = <int>[];
    for (var i = 0; ; i++) {
      final b = p[i];
      if (b == 0) break;

      bytes.add(b);
    }
    return latin1.decode(bytes);
  }

  String _readDeviceName(Pointer<Void> p) {
    if (Platform.isWindows) {
      return _readAnsi(p.cast<Uint8>());
    }

    return p.cast<Utf8>().toDartString();
  }

  bool setAudioDevice(int id) {
    final bass = BassLoader.instance;
=======
  bool prepare(String path) {
    return _withDevice<bool>(() {
      final bass = BassLoader.instance;
>>>>>>> 3787283 (feat: adicionado config para multiplos devices)

      if (_stream != 0) {
        bass.BASS_StreamFree(_stream);
        _stream = 0;
      }

      final cPath = path.toNativeUtf8();
      _stream = bass.BASS_StreamCreateFile(
        0,
        cPath.cast(),
        0,
        0,
        BassStreamFlags.PRESCAN | BassStreamFlags.FLOAT,
      );
      calloc.free(cPath);

      return _stream != 0;
    }, onFail: false);
  }

  bool play({bool restart = true}) {
    if (_stream == 0) return false;
    return _withDevice<bool>(() {
      final bass = BassLoader.instance;
      return bass.BASS_ChannelPlay(_stream, restart ? 1 : 0) != 0;
    }, onFail: false);
  }

  bool pause() {
    if (_stream == 0) return false;
    return _withDevice<bool>(() {
      final bass = BassLoader.instance;
      return bass.BASS_ChannelPause(_stream) != 0;
    }, onFail: false);
  }

  bool stop() {
    if (_stream == 0) return false;
    return _withDevice<bool>(() {
      final bass = BassLoader.instance;
      return bass.BASS_ChannelStop(_stream) != 0;
    }, onFail: false);
  }

  bool setVolume(double volume) {
    if (_stream == 0) return false;
    return _withDevice<bool>(() {
      final bass = BassLoader.instance;
      return bass.BASS_ChannelSetAttribute(_stream, 2, volume) != 0;
    }, onFail: false);
  }

  bool setPosition(double seconds) {
    if (_stream == 0) return false;
    return _withDevice<bool>(() {
      final bass = BassLoader.instance;
      final pos = bass.BASS_ChannelSeconds2Bytes(_stream, seconds);
      return bass.BASS_ChannelSetPosition(_stream, pos, 0) != 0;
    }, onFail: false);
  }

  double getPosition() {
    if (_stream == 0) return 0;
    return _withDevice<double>(() {
      final bass = BassLoader.instance;
      final pos = bass.BASS_ChannelGetPosition(_stream, 0);
      return bass.BASS_ChannelBytes2Seconds(_stream, pos);
    }, onFail: 0);
  }

  double getDuration() {
    if (_stream == 0) return 0;
    return _withDevice<double>(() {
      final bass = BassLoader.instance;
      final len = bass.BASS_ChannelGetLength(_stream, 0);
      return bass.BASS_ChannelBytes2Seconds(_stream, len);
    }, onFail: 0);
  }

  bool isPlaying() {
    if (_stream == 0) return false;
    return _withDevice<bool>(() {
      final bass = BassLoader.instance;
      return bass.BASS_ChannelIsActive(_stream) == BassChannelStatus.PLAYING;
    }, onFail: false);
  }

  Future<List<double>> loadWaveform(
    String path, {
    int points = 1500,
    int blockSize = 128,
  }) async {
    final bass = BassLoader.instance;

    _waveformCacheByPath[path] ??= {};
    if (_waveformCacheByPath[path]![points] != null) {
      return _waveformCacheByPath[path]![points]!;
    }

    // Waveform em modo decode não depende do device de saída
    final cPath = path.toNativeUtf8();
    final handle = bass.BASS_StreamCreateFile(
      0,
      cPath.cast(),
      0,
      0,
      BassStreamFlags.DECODE,
    );
    calloc.free(cPath);

    if (handle == 0) return [];

    final buffer = calloc<Float>(blockSize);
    final raw = <double>[];

    int read;
    do {
      read = bass.BASS_ChannelGetData(handle, buffer.cast<Void>(), blockSize);
      if (read > 0 && read <= blockSize) {
        final samples = buffer.asTypedList(read ~/ sizeOf<Float>());
        final rms =
            samples.map((v) => v.abs()).reduce((a, b) => a + b) / blockSize;
        raw.add(rms.isNaN ? 0.00 : rms);
      }
    } while (read > 0 && read <= blockSize);
    calloc.free(buffer);
    bass.BASS_StreamFree(handle);

    if (raw.isEmpty) return [];

    final max = raw.reduce((a, b) => a > b ? a : b);
    final normalized = raw.map((v) {
      final result = (v / max) * 1.5;
      return (double.parse(result.toStringAsFixed(3))).clamp(0.0, 1.0);
    }).toList();

    final stepSize = (normalized.length / points).floor();
    if (stepSize == 0) return normalized;

    final downsampled = <double>[];
    for (int i = 0; i < points; i++) {
      final start = i * stepSize;
      final end = start + stepSize;
      if (end <= normalized.length) {
        final segment = normalized.sublist(start, end);
        final avg = segment.reduce((a, b) => a > b ? a : b);
        downsampled.add(avg == 0.00 ? 0.02 : avg);
      }
    }

    _waveformCacheByPath[path]![points] = downsampled;
    return downsampled;
  }

  void clearWaveformCache(String path, {int? points}) {
    if (points != null) {
      _waveformCacheByPath[path]?.remove(points);
      if (_waveformCacheByPath[path]?.isEmpty ?? true) {
        _waveformCacheByPath.remove(path);
      }
    } else {
      _waveformCacheByPath.remove(path);
    }
  }

  void dispose() {
    _monitorTimer?.cancel();
    _statusController.close();
    _levelTicker?.cancel();
    _levelController.close();

    if (_stream != 0) {
      _withDevice<void>(() {
        final bass = BassLoader.instance;
        bass.BASS_StreamFree(_stream);
      });
      _stream = 0;
    }
  }

  void _startMonitoring() {
    _monitorTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_stream == 0) {
        music = '';
        return;
      }
      final status = _withDevice<int>(
        () => BassLoader.instance.BASS_ChannelIsActive(_stream),
        onFail: BassChannelStatus.STOPPED,
      ).toPlayerStatus();

      if (status != _lastStatus) {
        _lastStatus = status;
        _statusController.add(status);
      }
    });
  }

  void _startLevelTicker() {
    _levelTicker = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (_stream == 0) return;

      _withDevice<void>(() {
        final bass = BassLoader.instance;

        if (bass.BASS_ChannelIsActive(_stream) != BassChannelStatus.PLAYING) {
          _levelController.add(const LevelStereo(0, 0));
          return;
        }

        final level = bass.BASS_ChannelGetLevel(_stream);
        if (level == -1) {
          _levelController.add(const LevelStereo(0, 0));
          return;
        }

        final left = (level & 0xFFFF) / 32768.0;
        final right = ((level >> 16) & 0xFFFF) / 32768.0;
        _levelController.add(LevelStereo(left.clamp(0, 1), right.clamp(0, 1)));
      });
    });
  }
}
