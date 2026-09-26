import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/minigame/chicken_game.dart';

/// Is the mini-game open, and how did the last round go.
class MiniGame extends ChangeNotifier {
  MiniGame._();

  static final MiniGame instance = MiniGame._();

  bool _open = false;
  bool get open => _open;

  /// Called when the player goes back home (best score of the visit, or null).
  void Function(int? best)? onClosed;

  void show() {
    if (_open) return;
    _open = true;
    notifyListeners();
  }

  void close(int? best) {
    _open = false;
    notifyListeners();
    onClosed?.call(best);
  }
}

const _plum = Color(0xE62B1830);
const _gold = Color(0xFFFFD08A);
const _cream = Color(0xFFFFF4DE);
TextStyle _px(double s, [Color c = _cream]) => GoogleFonts.pixelifySans(fontSize: s, color: c, height: 1.15);

class MiniGameOverlay extends StatelessWidget {
  const MiniGameOverlay({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: MiniGame.instance,
        builder: (context, _) => MiniGame.instance.open ? const _MiniGameScreen() : const SizedBox.shrink(),
      );
}

class _MiniGameScreen extends StatefulWidget {
  const _MiniGameScreen();

  @override
  State<_MiniGameScreen> createState() => _MiniGameScreenState();
}

enum _Stage { intro, play, over }

class _MiniGameScreenState extends State<_MiniGameScreen> {
  static const _bestKey = 'dos_gatitos.chicken_best';
  final ChickenGame _game = ChickenGame();
  _Stage _stage = _Stage.intro;
  int _best = 0;
  int? _visitBest;
  int _last = 0;

  @override
  void initState() {
    super.initState();
    _game.onRoundOver = _roundOver;
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _best = p.getInt(_bestKey) ?? 0);
    }).catchError((_) {});
  }

  void _play() {
    setState(() => _stage = _Stage.play);
    _game.startRound();
  }

  Future<void> _roundOver(int score) async {
    final record = score > _best;
    setState(() {
      _last = score;
      _visitBest = (_visitBest ?? 0) < score ? score : _visitBest;
      if (record) _best = score;
      _stage = _Stage.over;
    });
    if (record) {
      try {
        (await SharedPreferences.getInstance()).setInt(_bestKey, score);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: _game)),
          SafeArea(
            child: Stack(
              children: [
                if (_stage == _Stage.play) _topBar(),
                if (_stage == _Stage.intro) _intro(),
                if (_stage == _Stage.over) _over(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({required List<Widget> children}) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 22),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: _plum,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold.withValues(alpha: 0.7), width: 2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      );

  Widget _button(String label, VoidCallback onTap, {bool primary = true}) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: primary ? _gold : const Color(0xFF45284D),
              foregroundColor: primary ? const Color(0xFF2B1830) : _cream,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: onTap,
            child: Text(label, style: _px(18, primary ? const Color(0xFF2B1830) : _cream)),
          ),
        ),
      );

  Widget _intro() => _panel(children: [
        Image.asset('assets/ui/logo.webp', height: 64),
        const SizedBox(height: 12),
        Text('¡Atrapá las gallinas!', style: _px(24, _gold), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text(
          'Tocá la pantalla y Sebas salta\na la gallina más cercana.\nCuando tiene el círculo dorado, ¡es tuya!\nLa dorada vale 5.',
          style: _px(15),
          textAlign: TextAlign.center,
        ),
        if (_best > 0) ...[const SizedBox(height: 8), Text('Récord: $_best', style: _px(14, _gold))],
        const SizedBox(height: 6),
        _button('¡Jugar!', _play),
        _button('Volver a casa', () => MiniGame.instance.close(_visitBest), primary: false),
      ]);

  Widget _over() => _panel(children: [
        Image.asset('assets/minigame/cat_win.webp', height: 120),
        const SizedBox(height: 6),
        Text('¡Se acabó!', style: _px(24, _gold)),
        const SizedBox(height: 6),
        Text(_last == 1 ? 'Atrapaste 1 gallina' : 'Atrapaste $_last gallinas', style: _px(18)),
        Text(_last >= _best && _last > 0 ? '¡Nuevo récord!' : 'Récord: $_best', style: _px(14, _gold)),
        const SizedBox(height: 6),
        _button('Otra vez', _play),
        _button('A casa', () => MiniGame.instance.close(_visitBest), primary: false),
      ]);

  Widget _topBar() => Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _pill(ValueListenableBuilder<int>(
              valueListenable: _game.score,
              builder: (_, v, _) => Text('Gallinas: $v', style: _px(17)),
            )),
            const Spacer(),
            _pill(ValueListenableBuilder<double>(
              valueListenable: _game.timeLeft,
              builder: (_, v, _) => Text('0:${v.ceil().toString().padLeft(2, '0')}', style: _px(17, v < 6 ? const Color(0xFFFF8F8F) : _cream)),
            )),
            const SizedBox(width: 8),
            _pill(GestureDetector(
              onTap: () => MiniGame.instance.close(_visitBest),
              child: const Icon(Icons.close_rounded, color: _cream, size: 20),
            )),
          ],
        ),
      );

  Widget _pill(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _plum,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _gold.withValues(alpha: 0.55), width: 1.5),
        ),
        child: child,
      );
}
