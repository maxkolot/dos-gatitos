import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_state.dart';
import '../features/audio/music.dart';
import '../features/audio/sfx.dart';
import '../features/pet/sr_fer.dart';
import '../features/sleep/sleep.dart';
import 'guide.dart';
import 'minigame_overlay.dart';
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

TextStyle _px(
  double size, {
  Color color = _cream,
  FontWeight weight = FontWeight.w600,
}) => GoogleFonts.pixelifySans(
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: 1.1,
);

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
    Sfx.instance.play(action == TamagotchiAction.jugar ? 'ui_open' : 'ui_tap');
    if (action == TamagotchiAction.jugar) {
      Music.instance.fadeTo(
        'baile',
        out: const Duration(milliseconds: 500),
        fadeIn: const Duration(milliseconds: 900),
      );
      MiniGame.instance.show(); // stats and lines come when they are back home
      return;
    }
    if (action == TamagotchiAction.preguntar) {
      _show(
        'Tocá a Sebastián o a Maxito: se acercan a hablar. El chat llega pronto.',
      );
      return;
    }
    // «Hablar» is with whoever is in front of the camera (or both chat together)
    final withWho = Sebastian.isFocused
        ? 'sebastian'
        : MaxitoController.instance.state.isCloseUp
        ? 'maxito'
        : null;
    final director = StageDirector.instance;
    final result =
        director?.act(action, conQuien: withWho) ??
        tamagotchi.activar(action, conQuien: withWho);
    if (result != null) _show(_summary(result));
  }

  /// "Poner música · Ánimo +8 · Social +6 · Conexión +2"
  String _summary(ActionResult r) {
    final totals = <StatKind, double>{};
    for (final perCat in r.cambios.values) {
      perCat.forEach(
        (k, v) => totals[k] = (totals[k] ?? 0) + v / r.cambios.length,
      );
    }
    String fmt(double v) => '${v >= 0 ? '+' : '−'}${v.abs().round()}';
    final parts = <String>[
      for (final e in totals.entries.where((e) => e.value.abs() >= 0.5))
        '${e.key.labelEs} ${fmt(e.value)}',
      if (r.cambioConexion.abs() >= 0.5) 'Conexión ${fmt(r.cambioConexion)}',
    ];
    return [r.labelEs, ...parts].join(' · ') +
        (r.nota != null ? '\n${r.nota}' : '');
  }

  @override
  Widget build(BuildContext context) {
    // the header sits a bit into the top safe area (still clear of the notch / island)
    final top = MediaQuery.viewPaddingOf(context).top;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, top > 0 ? top - 14 : 4, 8, 8),
        child: ListenableBuilder(
          listenable: tamagotchi,
          builder: (context, _) => Column(
            children: [
              _Measured(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/ui/logo.webp',
                      height: 52,
                      filterQuality: FilterQuality.medium,
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: Guide.instance.show,
                      child: _StatsPanel(),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _toast == null
                    ? const SizedBox(height: 0)
                    : Container(
                        key: ValueKey(_toast),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _panel,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _gold.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          _toast!,
                          textAlign: TextAlign.center,
                          style: _px(13),
                        ),
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

/// Reports where the header ends (close-ups and bubbles stay below it).
class _Measured extends StatefulWidget {
  const _Measured({required this.child});

  final Widget child;

  @override
  State<_Measured> createState() => _MeasuredState();
}

class _MeasuredState extends State<_Measured> {
  final _key = GlobalKey();

  void _measure(_) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      hudBottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

/// A gentle pulsing glow around a button the characters are asking for.
class _Glow extends StatefulWidget {
  const _Glow({required this.on, required this.child, this.radius = 9});

  final bool on;
  final Widget child;
  final double radius;

  @override
  State<_Glow> createState() => _GlowState();
}

class _GlowState extends State<_Glow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.on) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: 0.35 + 0.5 * _c.value),
              blurRadius: 6 + 10 * _c.value,
              spreadRadius: 1 + 2 * _c.value,
            ),
          ],
        ),
        child: child,
      ),
      child: widget.child,
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
          Expanded(
            child: _PetStats(
              name: 'Sebastián',
              color: _sebColor,
              stats: tamagotchi.sebastian,
            ),
          ),
          const SizedBox(width: 8),
          _Bond(value: tamagotchi.conexion),
          const SizedBox(width: 8),
          Expanded(
            child: _PetStats(
              name: 'Maxito',
              color: _maxColor,
              stats: tamagotchi.maxito,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Llamar a Sr. Fer',
            onPressed: SrFer.callHim,
            icon: const Icon(Icons.pets_rounded, color: _gold, size: 20),
          ),
          ValueListenableBuilder<TamagotchiAction?>(
            valueListenable: wish,
            builder: (context, w, child) => _Glow(
              on: w == TamagotchiAction.dormir,
              radius: 20,
              child: child!,
            ),
            child: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Dormir (8 horas)',
              onPressed: () {
                Music.instance.start();
                Sfx.instance.play('ui_tap');
                Sleep.instance.start();
              },
              icon: const Icon(Icons.nightlight_round, color: _gold, size: 20),
            ),
          ),
          ListenableBuilder(
            listenable: Music.instance,
            builder: (context, _) => IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: Music.instance.muted
                  ? 'Activar sonido'
                  : 'Silenciar sonido',
              onPressed: Music.instance.toggleMute,
              icon: Icon(
                Music.instance.muted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                color: _gold,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetStats extends StatelessWidget {
  const _PetStats({
    required this.name,
    required this.color,
    required this.stats,
  });

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
        _Bar(
          icon: Icons.sentiment_satisfied_alt_rounded,
          value: stats.animo,
          color: const Color(0xFFFF8FB1),
          label: 'Ánimo',
        ),
        _Bar(
          icon: Icons.bolt_rounded,
          value: stats.energia,
          color: const Color(0xFFFFD35C),
          label: 'Energía',
        ),
        _Bar(
          icon: Icons.favorite_rounded,
          value: stats.carino,
          color: const Color(0xFFFF5C7A),
          label: 'Cariño',
        ),
        _Bar(
          icon: Icons.forum_rounded,
          value: stats.social,
          color: const Color(0xFF7FD3C4),
          label: 'Social',
        ),
      ],
    );
  }
}

/// A segmented pixel bar (10 blocks).
class _Bar extends StatelessWidget {
  const _Bar({
    required this.icon,
    required this.value,
    required this.color,
    required this.label,
  });

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
          const Icon(
            Icons.favorite_rounded,
            color: Color(0xFFFF5C8A),
            size: 28,
          ),
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
    (TamagotchiAction.cenar, Icons.restaurant_rounded, 'Cenar'),
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
                        ValueListenableBuilder<TamagotchiAction?>(
                          valueListenable: wish,
                          builder: (context, w, child) =>
                              _Glow(on: w == action, child: child!),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF45284D),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: _gold, width: 1.5),
                            ),
                            child: Icon(icon, color: _cream, size: 22),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          style: _px(10),
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                        ),
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
