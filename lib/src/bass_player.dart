import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:bass_flutter/src/ffi/bass_bindings.dart';
import 'package:ffi/ffi.dart';
import 'package:bass_flutter/src/ffi/bass_constants.dart';
import 'package:bass_flutter/src/ffi/bass_ffi_loader.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert' show latin1;

/// Enum com os possíveis status de reprodução
enum BassPlayerStatus { stopped, playing, stalled, paused, unknown }

/// Extensão para converter código int da BASS em [BassPlayerStatus]
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

/// Representa um nível estéreo (L e R entre 0.0 e 1.0)
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

/// Classe de player de áudio baseada na BASS
class BassPlayer {
  /// ID único da instância (opcional para controle externo)
  final int id;

  String? music;

  int _stream = 0;

  final _statusController = StreamController<BassPlayerStatus>.broadcast();

  /// Stream com o status de reprodução (playing, stopped etc)
  Stream<BassPlayerStatus> get statusStream => _statusController.stream;

  final _levelController = StreamController<LevelStereo>.broadcast();

  /// Stream com níveis estéreo contínuos (para VU meter)
  Stream<LevelStereo> get levelStream => _levelController.stream;

  BassPlayerStatus _lastStatus = BassPlayerStatus.unknown;
  Timer? _monitorTimer;
  Timer? _levelTicker;

  // Cache da waveform por stream e resolução
  final Map<String, Map<int, List<double>>> _waveformCacheByPath = {};

  /// Cria uma nova instância de player com o [id] informado
  BassPlayer(this.id) {
    _startMonitoring();
    _startLevelTicker();
  }

  /// Inicia reprodução de um arquivo [path].
  /// Se [restart] for true, reinicia mesmo que já esteja tocando.
  bool play(String path, {bool restart = true}) {
    final bass = BassLoader.instance;

    if (_stream != 0 && restart) {
      bass.BASS_StreamFree(_stream);
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

    if (_stream == 0) return false;

    return bass.BASS_ChannelPlay(_stream, restart ? 1 : 0) != 0;
  }

  /// Pausa a reprodução atual
  bool pause() {
    final bass = BassLoader.instance;
    return _stream != 0 ? bass.BASS_ChannelPause(_stream) != 0 : false;
  }

  /// Interrompe completamente a reprodução atual
  bool stop() {
    final bass = BassLoader.instance;
    return _stream != 0 ? bass.BASS_ChannelStop(_stream) != 0 : false;
  }

  /// Altera o volume (0.0 a 1.0)
  bool setVolume(double volume) {
    final bass = BassLoader.instance;
    return _stream != 0
        ? bass.BASS_ChannelSetAttribute(_stream, 2, volume) != 0
        : false;
  }

  /// Move a reprodução para a posição em [seconds]
  bool setPosition(double seconds) {
    final bass = BassLoader.instance;
    if (_stream == 0) return false;
    final pos = bass.BASS_ChannelSeconds2Bytes(_stream, seconds);
    return bass.BASS_ChannelSetPosition(_stream, pos, 0) != 0;
  }

  /// Retorna a posição atual (em segundos)
  double getPosition() {
    final bass = BassLoader.instance;
    if (_stream == 0) return 0;
    final pos = bass.BASS_ChannelGetPosition(_stream, 0);
    return bass.BASS_ChannelBytes2Seconds(_stream, pos);
  }

  /// Retorna a duração total do áudio (em segundos)
  double getDuration() {
    final bass = BassLoader.instance;
    if (_stream == 0) return 0;
    final len = bass.BASS_ChannelGetLength(_stream, 0);
    return bass.BASS_ChannelBytes2Seconds(_stream, len);
  }

  /// Retorna true se o áudio está atualmente tocando
  bool isPlaying() {
    final bass = BassLoader.instance;
    if (_stream == 0) return false;
    return bass.BASS_ChannelIsActive(_stream) == BassChannelStatus.PLAYING;
  }

  int getDevice() {
    final bass = BassLoader.instance;

    return bass.BASS_GetDevice();
  }

  /// Retorna a lista de dispositivos de áudio disponíveis no sistema.
  ///
  /// Utiliza a função `BASS_GetDeviceInfo` da biblioteca BASS para iterar
  /// sobre todos os dispositivos detectados, coletando o `id` (índice do
  /// dispositivo) e o `name` (nome descritivo fornecido pelo sistema/driver).
  ///
  /// Apenas dispositivos ativos são retornados, garantindo que o usuário
  /// possa selecionar saídas de áudio válidas para reprodução.
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

    // 1) Garante init do device alvo
    final inited = bass.BASS_Init(id, 44100, 0, nullptr, nullptr) != 0;
    if (!inited) {
      final err = bass.BASS_ErrorGetCode();
      // 14 = BASS_ERROR_ALREADY (já inicializado) → ok
      if (err != 14) {
        debugPrint('BASS_Init($id) falhou: $err');
        return false;
      }
    }

    // 2) Define o device "current" desta thread
    if (bass.BASS_SetDevice(id) == 0) {
      final err = bass.BASS_ErrorGetCode();
      debugPrint('BASS_SetDevice($id) falhou: $err');
      return false;
    }

    return true;
  }

  /// Gera a waveform completa com [points] amostras (default: 1500)
  /// Cada ponto representa os picos L/R em um bloco da música
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
        final avg = segment.reduce((a, b) => a > b ? a : b); // valor máximo

        downsampled.add(avg == 0.00 ? 0.02 : avg);
      }
    }

    _waveformCacheByPath[path]![points] = downsampled;

    return downsampled;
  }

  /// Limpa o cache da waveform apenas do stream atual
  /// Remove a waveform do cache por [path].
  /// Se [points] for informado, remove só aquela resolução.
  /// Caso contrário, remove todas.
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

  /// Libera recursos do player (stream, timers, controllers)
  void dispose() {
    _monitorTimer?.cancel();
    _statusController.close();
    _levelTicker?.cancel();
    _levelController.close();

    final bass = BassLoader.instance;
    if (_stream != 0) {
      bass.BASS_StreamFree(_stream);
    }
  }

  // Inicia verificação periódica do status (emite apenas quando muda)
  void _startMonitoring() {
    _monitorTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_stream == 0) {
        music = '';
        return;
      }

      final bass = BassLoader.instance;
      final status = bass.BASS_ChannelIsActive(_stream).toPlayerStatus();

      if (status != _lastStatus) {
        _lastStatus = status;
        _statusController.add(status);
      }
    });
  }

  // Inicia leitura contínua do nível estéreo (VU meter)
  void _startLevelTicker() {
    _levelTicker = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (_stream == 0) return;

      final bass = BassLoader.instance;

      // Verifica se ainda está tocando
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
  }
}
