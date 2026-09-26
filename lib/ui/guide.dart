import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/audio/sfx.dart';

/// «¿Cómo se juega?»: shown once on the first launch, and again whenever the
/// player taps the stats panel.
class Guide extends ChangeNotifier {
  Guide._();

  static final Guide instance = Guide._();
  static const _key = 'dos_gatitos.guide_seen';

  bool _open = false;
  bool get open => _open;

  /// First launch only.
  Future<void> showFirstTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_key) ?? false) return;
      await prefs.setBool(_key, true);
    } catch (_) {}
    show();
  }

  void show() {
    Sfx.instance.play('ui_open');
    _open = true;
    notifyListeners();
  }

  void close() {
    _open = false;
    notifyListeners();
  }
}

const _gold = Color(0xFFFFD08A);
const _cream = Color(0xFFFFF4DE);

class GuideOverlay extends StatelessWidget {
  const GuideOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Guide.instance,
      builder: (context, _) {
        if (!Guide.instance.open) return const SizedBox.shrink();
        TextStyle px(double s, [Color c = _cream]) => GoogleFonts.pixelifySans(fontSize: s, color: c, height: 1.25);
        Widget row(List<Widget> icons, String text) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 52, child: Wrap(spacing: 2, runSpacing: 2, children: icons)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(text, style: px(14.5))),
                ],
              ),
            );
        Icon ic(IconData d, Color c) => Icon(d, size: 16, color: c);
        return GestureDetector(
          onTap: Guide.instance.close,
          child: ColoredBox(
            color: const Color(0xB3000000),
            child: SafeArea(
              child: Center(
                child: GestureDetector(
                  onTap: () {}, // taps inside the card do not close it
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xF22B1830),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _gold.withValues(alpha: 0.75), width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Text('¿Cómo se juega?', style: px(22, _gold))),
                        const SizedBox(height: 14),
                        row([
                          ic(Icons.sentiment_satisfied_alt_rounded, const Color(0xFFFF8FB1)),
                          ic(Icons.bolt_rounded, const Color(0xFFFFD35C)),
                          ic(Icons.favorite_rounded, const Color(0xFFFF5C7A)),
                          ic(Icons.forum_rounded, const Color(0xFF7FD3C4)),
                        ], 'Las barras de cada uno: Ánimo, Energía, Cariño y Social. El corazón grande es su Conexión.'),
                        row([ic(Icons.music_note_rounded, _cream), ic(Icons.wine_bar_rounded, _cream), ic(Icons.restaurant_rounded, _cream)],
                            'Con los botones de abajo los cuidás: música, vino, charlar, abrazos, jugar, cenar. Cada uno sube sus barras.'),
                        row([ic(Icons.priority_high_rounded, _gold)],
                            'Cuando les falta algo te lo piden, y el botón que necesitan brilla. ¡Hacelos felices!'),
                        row([ic(Icons.touch_app_rounded, _cream)], 'Tocá a uno de los dos y se acerca a vos.'),
                        row([ic(Icons.nightlight_round, _gold)], 'La luna los manda a dormir: vuelven en 8 horas con toda la energía.'),
                        row([ic(Icons.toys_rounded, _cream)], '«Jugar» abre el juego de la azotea: tocá una gallina y Sebas salta a atraparla.'),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _gold,
                              foregroundColor: const Color(0xFF2B1830),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: Guide.instance.close,
                            child: Text('¡Entendido!', style: px(18, const Color(0xFF2B1830))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
