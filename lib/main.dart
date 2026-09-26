import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_state.dart';
import 'features/audio/music.dart';
import 'game.dart';
import 'ui/game_hud.dart';
import 'ui/ready_signal.dart';
import 'ui/splash_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(tamagotchi.cargar()); // saved stats + what happened while away
  runApp(const DosGatitosApp());
  unawaited(appReady);
}

/// Everything the first screen needs: the game (room, both characters and their
/// animations), the pixel font and the music file. Never waits more than 12 s.
final Future<void> appReady = Future.wait<void>([
  gameLoaded.future,
  GoogleFonts.pendingFonts([GoogleFonts.pixelifySans(fontWeight: FontWeight.w600)]).then((_) {}, onError: (_) {}),
  Music.instance.preload(),
]).timeout(const Duration(seconds: 12), onTimeout: () => const []).then((_) {
  signalReady(); // web: the HTML video splash fades out
  // the native apps may start the music right away; browsers need a first touch
  if (!kIsWeb) unawaited(Music.instance.start());
});

class DosGatitosApp extends StatelessWidget {
  const DosGatitosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dos Gatitos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF1D1B2E),
        // the first touch anywhere starts the music (browsers need a gesture)
        body: Listener(
          onPointerDown: (_) => Music.instance.start(),
          child: Stack(
            children: [
              // the widget owns the game: rebuilds and app restarts never re-attach a used instance
              Positioned.fill(
                child: GameWidget<DosGatitosGame>.controlled(
                  gameFactory: DosGatitosGame.new,
                  errorBuilder: (context, error) => _GameError(error),
                ),
              ),
              const Positioned.fill(child: GameHud()),
              if (!hasHtmlSplash) Positioned.fill(child: SplashOverlay(ready: appReady)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Instead of a grey box: what went wrong, readable on a screenshot.
class _GameError extends StatelessWidget {
  const _GameError(this.error);

  final Object error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1D1B2E),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'La escena no cargó.\n$error',
            textAlign: TextAlign.center,
            style: GoogleFonts.pixelifySans(fontSize: 14, color: const Color(0xFFFFD08A)),
          ),
        ),
      ),
    );
  }
}
