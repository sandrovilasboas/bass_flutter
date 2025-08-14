import 'package:flutter_test/flutter_test.dart';
import 'package:bass_flutter/src/ffi/bass_initializer.dart';
import 'package:bass_flutter/src/bass_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const audioPath = 'test/assets/stereo.mp3';

  setUpAll(() {
    final ok = BassInitializer.init();
    expect(ok, true, reason: 'BASS_Init falhou');
  });

  group('BassPlayer', () {
    test('Cria player e inicializa com sucesso', () {
      final player = BassPlayer(1);
      expect(player, isA<BassPlayer>());
      player.dispose();
    });

    test('Toca áudio com sucesso', () async {
      final player = BassPlayer(2);
      final ok = player.play(audioPath);
      expect(ok, true, reason: 'Falha ao tocar');
      await Future.delayed(Duration(milliseconds: 300));
      expect(player.isPlaying(), true);
      player.dispose();
    });

    test('Stream de status emite PLAYING', () async {
      final player = BassPlayer(3);
      final statuses = <BassPlayerStatus>[];
      final sub = player.statusStream.listen(statuses.add);
      final ok = player.play(audioPath);
      expect(ok, true);
      await Future.delayed(Duration(milliseconds: 400));
      expect(statuses.contains(BassPlayerStatus.playing), true);
      await sub.cancel();
      player.dispose();
    });

    test('Waveform estático com 300 pontos', () async {
      try {
        final player = BassPlayer(4);
        final waveform = await player.loadWaveform(audioPath);
        expect(waveform.length, 1500);
        expect(waveform.first, isA<double>());
        player.dispose();
      } catch (e) {
        print(e.toString());
        fail(e.toString());
      }
    });
  });
}
