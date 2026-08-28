import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/jarvis_theme.dart';
import '../widgets/glass_container.dart';

enum _Direction { up, down, left, right }

/// Simple Snake mini-game, rendered on a fixed grid with plain Flutter
/// widgets (no CustomPainter/game engine needed for a grid this size).
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int _cols = 15;
  static const int _rows = 20;
  static const Duration _startTick = Duration(milliseconds: 220);
  static const Duration _minTick = Duration(milliseconds: 80);

  final _random = Random();

  late List<Point<int>> _snake;
  late Point<int> _food;
  _Direction _direction = _Direction.right;
  _Direction _pendingDirection = _Direction.right;
  int _score = 0;
  bool _gameOver = false;
  Timer? _timer;
  Duration _tickDuration = _startTick;
  Offset _dragAccumulator = Offset.zero;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    final startY = _rows ~/ 2;
    _snake = [
      Point(7, startY),
      Point(6, startY),
      Point(5, startY),
    ];
    _direction = _Direction.right;
    _pendingDirection = _Direction.right;
    _score = 0;
    _gameOver = false;
    _tickDuration = _startTick;
    _food = _randomFreeCell();
    _timer?.cancel();
    _timer = Timer.periodic(_tickDuration, (_) => _tick());
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_tickDuration, (_) => _tick());
  }

  Point<int> _randomFreeCell() {
    while (true) {
      final candidate = Point(_random.nextInt(_cols), _random.nextInt(_rows));
      if (!_snake.contains(candidate)) return candidate;
    }
  }

  Point<int> _offsetFor(_Direction direction) {
    switch (direction) {
      case _Direction.up:
        return const Point(0, -1);
      case _Direction.down:
        return const Point(0, 1);
      case _Direction.left:
        return const Point(-1, 0);
      case _Direction.right:
        return const Point(1, 0);
    }
  }

  bool _isOpposite(_Direction a, _Direction b) {
    return (a == _Direction.up && b == _Direction.down) ||
        (a == _Direction.down && b == _Direction.up) ||
        (a == _Direction.left && b == _Direction.right) ||
        (a == _Direction.right && b == _Direction.left);
  }

  void _setDirection(_Direction direction) {
    if (_gameOver || _isOpposite(direction, _direction)) return;
    _pendingDirection = direction;
  }

  void _tick() {
    if (_gameOver) return;
    _direction = _pendingDirection;
    final offset = _offsetFor(_direction);
    final head = _snake.first;
    final newHead = Point(head.x + offset.x, head.y + offset.y);

    final hitWall = newHead.x < 0 || newHead.x >= _cols || newHead.y < 0 || newHead.y >= _rows;
    final hitSelf = _snake.contains(newHead) && newHead != _snake.last;

    if (hitWall || hitSelf) {
      _timer?.cancel();
      setState(() => _gameOver = true);
      _showGameOverDialog();
      return;
    }

    setState(() {
      _snake.insert(0, newHead);
      if (newHead == _food) {
        _score++;
        _food = _randomFreeCell();
        final nextMillis = max(_minTick.inMilliseconds, _tickDuration.inMilliseconds - 4);
        _tickDuration = Duration(milliseconds: nextMillis);
        _restartTimer();
      } else {
        _snake.removeLast();
      }
    });
  }

  void _showGameOverDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text('Punkte: $_score'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(_startGame);
            },
            child: const Text('Neu starten'),
          ),
        ],
      ),
    );
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    _dragAccumulator += details.delta;
    const threshold = 12.0;
    if (_dragAccumulator.dx.abs() > threshold || _dragAccumulator.dy.abs() > threshold) {
      if (_dragAccumulator.dx.abs() > _dragAccumulator.dy.abs()) {
        _setDirection(_dragAccumulator.dx > 0 ? _Direction.right : _Direction.left);
      } else {
        _setDirection(_dragAccumulator.dy > 0 ? _Direction.down : _Direction.up);
      }
      _dragAccumulator = Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Snake')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  'Punkte: $_score',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: JarvisColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _cols / _rows,
                    child: GestureDetector(
                      onPanUpdate: _handlePanUpdate,
                      child: Container(
                        decoration: BoxDecoration(
                          color: JarvisColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: JarvisColors.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _cols,
                            ),
                            itemCount: _cols * _rows,
                            itemBuilder: (context, index) {
                              final point = Point(index % _cols, index ~/ _cols);
                              final isHead = point == _snake.first;
                              final isBody = !isHead && _snake.contains(point);
                              final isFood = point == _food;
                              Color color = Colors.transparent;
                              if (isHead) {
                                color = JarvisColors.accentGlow;
                              } else if (isBody) {
                                color = JarvisColors.accent;
                              } else if (isFood) {
                                color = JarvisColors.error;
                              }
                              return Padding(
                                padding: const EdgeInsets.all(1),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GlassContainer(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up),
                      onPressed: () => _setDirection(_Direction.up),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_left),
                          onPressed: () => _setDirection(_Direction.left),
                        ),
                        const SizedBox(width: 48),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_right),
                          onPressed: () => _setDirection(_Direction.right),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: () => _setDirection(_Direction.down),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
