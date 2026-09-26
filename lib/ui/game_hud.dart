import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_state.dart';
import '../features/audio/music.dart';
import '../features/characters/maxito/maxito_state.dart';
import '../features/characters/sebastian/sebastian_character.dart';
import '../features/stage/stage_director.dart';
import '../features/tamagotchi/tamagotchi.dart';

/// Pixel HUD over the room: both characters' stats on top, the six actions at
/// the bottom, a short line with what an action changed.
class GameHud extends StatefulWidget {
  const GameHud({super.key});

  @override
  State<GameHud> createState() => _GameHudState();
}

const _panel = Color(0xE62B1830);
const _gold = Color(0xFFFFD08A);
const _cream = Color(0xFFFFF4DE);
const _sebColor = Color(0xFF8EC5FF);
const _maxColor = Color(0xFFFF9A4D);

TextStyle _px(double size, {Color color = _cream, FontWeight weight = FontWeight.w600}) =>
    GoogleFonts.pixelifySans(fontSize: size, color: color, fontWeight: weight, height: 1.1);

class _GameHudState extends State<GameHud> {
  String? _toast;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _show(String text) {
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _onAction(TamagotchiAction action) {
    Music.instance.start();
    if (action == TamagotchiAction.preguntar) {
      _show('Tocá a Sebastián o a Maxito: se acercan a hablar. El chat llega pronto.');
      return;
    }
    // «Hablar» is with whoever is in front of the camera (or both chat together)
    final withWho = Sebastian.isFocused
        ? 'sebastian'
        : MaxitoController.instance.state.isCloseUp
            ? 'maxito'
            : null;
    final director = StageDirector.instance;
    final result = director?.act(action, conQuien: withWho) ?? tamagotchi.activar(action, conQuien: withWho);
    if (result != null) _show(_summary(result));
  }

  /// "Poner música · Ánimo +8 · Social +6 · Conexión +2"
  String _summary(ActionResult r) {
    final totals = <StatKind, double>{};
    for (final perCat in r.cambios.values) {
      perCat.forEach((k, v) => totals[k] = (totals[k] ?? 0) + v / r.cambios.length);
    }
    String fmt(double v) => '${v >= 0 ? '+' : '−'}${v.abs().round()}';
    final parts = <String>[
      for (final e in totals.entries.where((e) => e.value.abs() >= 0.5)) '${e.key.labelEs} ${fmt(e.value)}',
      if (r.cambioConexion.abs() >= 0.5) 'Conexión ${fmt(r.cambioConexion)}',
    ];
    return [r.labelEs, ...parts].join(' · ') + (r.nota != null ? '\n${r.nota}' : '');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: ListenableBuilder(
          listenable: tamagotchi,
          builder: (context, _) => Column(
            children: [
              _StatsPanel(),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _toast == null
                    ? const SizedBox(height: 0)
                    : Container(
                        key: ValueKey(_toast),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _panel,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _gold.withValues(alpha: 0.6), width: 1.5),
                        ),
                        child: Text(_toast!, textAlign: TextAlign.center, style: _px(13)),
                      ),
              ),
              _ActionBar(onAction: _onAction),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _PetStats(name: 'Sebastián', color: _sebColor, stats: tamagotchi.sebastian)),
          const SizedBox(width: 8),
          _Bond(value: tamagotchi.conexion),
          const SizedBox(width: 8),
          Expanded(child: _PetStats(name: 'Maxito', color: _maxColor, stats: tamagotchi.maxito)),
          ListenableBuilder(
            listenable: Music.instance,
            builder: (context, _) => IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: Music.instance.muted ? 'Activar música' : 'Silenciar música',
              onPressed: Music.instance.toggleMute,
              icon: Icon(Music.instance.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: _gold, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetStats extends StatelessWidget {
  const _PetStats({required this.name, required this.color, required this.stats});

  final String name;
  final Color color;
  final CharacterState stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: _px(14, color: color)),
        const SizedBox(height: 4),
        _Bar(icon: Icons.sentiment_satisfied_alt_rounded, value: stats.animo, color: const Color(0xFFFF8FB1), label: 'Ánimo'),
        _Bar(icon: Icons.bolt_rounded, value: stats.energia, color: const Color(0xFFFFD35C), label: 'Energía'),
        _Bar(icon: Icons.favorite_rounded, value: stats.carino, color: const Color(0xFFFF5C7A), label: 'Cariño'),
        _Bar(icon: Icons.forum_rounded, value: stats.social, color: const Color(0xFF7FD3C4), label: 'Social'),
      ],
    );
  }
}

/// A segmented pixel bar (10 blocks).
class _Bar extends StatelessWidget {
  const _Bar({required this.icon, required this.value, required this.color, required this.label});

  final IconData icon;
  final double value;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final filled = (value / 10).round().clamp(0, 10);
    return Semantics(
      label: '$label ${value.round()}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            for (var i = 0; i < 10; i++)
              Container(
                width: 7,
                height: 6,
                margin: const EdgeInsets.only(right: 1.5),
                color: i < filled ? color : const Color(0x33FFFFFF),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bond extends StatelessWidget {
  const _Bond({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Conexión ${value.round()}',
      child: Column(
        children: [
          const Icon(Icons.favorite_rounded, color: Color(0xFFFF5C8A), size: 28),
          Text('${value.round()}', style: _px(15)),
          Text('Conexión', style: _px(9.5, color: _gold)),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.onAction});

  final void Function(TamagotchiAction) onAction;

  static const _items = <(TamagotchiAction, IconData, String)>[
    (TamagotchiAction.ponerMusica, Icons.music_note_rounded, 'Música'),
    (TamagotchiAction.servirVino, Icons.wine_bar_rounded, 'Vino'),
    (TamagotchiAction.hablar, Icons.forum_rounded, 'Hablar'),
    (TamagotchiAction.darUnAbrazo, Icons.favorite_rounded, 'Abrazo'),
    (TamagotchiAction.jugar, Icons.toys_rounded, 'Jugar'),
    (TamagotchiAction.preguntar, Icons.help_rounded, 'Preguntar'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final (action, icon, label) in _items)
            Expanded(
              child: Semantics(
                button: true,
                label: label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onAction(action),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF45284D),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: _gold, width: 1.5),
                          ),
                          child: Icon(icon, color: _cream, size: 22),
                        ),
                        const SizedBox(height: 3),
                        Text(label, style: _px(10.5), maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
