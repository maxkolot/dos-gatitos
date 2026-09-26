import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'features/audio/music.dart';
import 'game.dart';
import 'ui/game_hud.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(tamagotchi.cargar()); // saved stats + what happened while away
  runApp(const DosGatitosApp());
}

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
              Positioned.fill(child: GameWidget(game: _game)),
              const Positioned.fill(child: GameHud()),
            ],
          ),
        ),
      ),
    );
  }
}

final DosGatitosGame _game = DosGatitosGame();
