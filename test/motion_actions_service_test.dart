import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_mobile/services/motion_actions_service.dart';
import 'package:sensors_plus/sensors_plus.dart';

AccelerometerEvent _event({required double x, required double y, required double z, required int atMs}) =>
    AccelerometerEvent(x, y, z, DateTime.fromMillisecondsSinceEpoch(atMs));

void main() {
  group('Face-down detection', () {
    test('fires onFaceDown once after being flat and face-down for the sustain duration', () async {
      final events = <AccelerometerEvent>[
        _event(x: 0, y: 0, z: -9.7, atMs: 0),
        _event(x: 0, y: 0, z: -9.7, atMs: 300),
        _event(x: 0, y: 0, z: -9.7, atMs: 650), // >= 600ms since the first sample
        _event(x: 0, y: 0, z: -9.7, atMs: 900), // still face-down, must not re-fire
      ];
      var faceDownCount = 0;
      var faceUpCount = 0;
      final service = MotionActionsService(streamFactory: () => Stream.fromIterable(events));

      service.start(
        onFaceDown: () => faceDownCount++,
        onFaceUp: () => faceUpCount++,
        onShake: () {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(faceDownCount, 1);
      expect(faceUpCount, 0);
      service.stop();
    });

    test('does not fire when face-down only briefly (below the sustain duration)', () async {
      final events = <AccelerometerEvent>[
        _event(x: 0, y: 0, z: -9.7, atMs: 0),
        _event(x: 0, y: 0, z: -9.7, atMs: 200), // still under 600ms
        _event(x: 0, y: 0, z: 9.8, atMs: 250), // flipped back up before sustain elapsed
      ];
      var faceDownCount = 0;
      final service = MotionActionsService(streamFactory: () => Stream.fromIterable(events));

      service.start(onFaceDown: () => faceDownCount++, onFaceUp: () {}, onShake: () {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(faceDownCount, 0);
      service.stop();
    });

    test('does not fire when tilted but not flat (large x/y component)', () async {
      final events = <AccelerometerEvent>[
        _event(x: 8, y: 0, z: -9.0, atMs: 0),
        _event(x: 8, y: 0, z: -9.0, atMs: 700),
      ];
      var faceDownCount = 0;
      final service = MotionActionsService(streamFactory: () => Stream.fromIterable(events));

      service.start(onFaceDown: () => faceDownCount++, onFaceUp: () {}, onShake: () {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(faceDownCount, 0);
      service.stop();
    });

    test('fires onFaceUp once after flipping back from a confirmed face-down', () async {
      final events = <AccelerometerEvent>[
        _event(x: 0, y: 0, z: -9.7, atMs: 0),
        _event(x: 0, y: 0, z: -9.7, atMs: 650),
        _event(x: 0, y: 0, z: 9.8, atMs: 900),
        _event(x: 0, y: 0, z: 9.8, atMs: 950), // stays up, must not re-fire
      ];
      var faceDownCount = 0;
      var faceUpCount = 0;
      final service = MotionActionsService(streamFactory: () => Stream.fromIterable(events));

      service.start(
        onFaceDown: () => faceDownCount++,
        onFaceUp: () => faceUpCount++,
        onShake: () {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(faceDownCount, 1);
      expect(faceUpCount, 1);
      service.stop();
    });
  });

  group('Shake detection', () {
    test('fires onShake after several magnitude spikes within the rolling window', () async {
      final events = <AccelerometerEvent>[
        _event(x: 25, y: 0, z: 0, atMs: 0),
        _event(x: 25, y: 0, z: 0, atMs: 100),
        _event(x: 25, y: 0, z: 0, atMs: 200),
      ];
      var shakeCount = 0;
      final service = MotionActionsService(streamFactory: () => Stream.fromIterable(events));

      service.start(onFaceDown: () {}, onFaceUp: () {}, onShake: () => shakeCount++);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(shakeCount, 1);
      service.stop();
    });

    test('does not fire on a single isolated spike', () async {
      final events = <AccelerometerEvent>[
        _event(x: 25, y: 0, z: 0, atMs: 0),
        _event(x: 0, y: 0, z: 9.8, atMs: 100),
        _event(x: 0, y: 0, z: 9.8, atMs: 200),
      ];
      var shakeCount = 0;
      final service = MotionActionsService(streamFactory: () => Stream.fromIterable(events));

      service.start(onFaceDown: () {}, onFaceUp: () {}, onShake: () => shakeCount++);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(shakeCount, 0);
      service.stop();
    });

    test('does not fire again during the cooldown after a shake was detected', () async {
      final events = <AccelerometerEvent>[
        _event(x: 25, y: 0, z: 0, atMs: 0),
        _event(x: 25, y: 0, z: 0, atMs: 100),
        _event(x: 25, y: 0, z: 0, atMs: 200), // fires here
        _event(x: 25, y: 0, z: 0, atMs: 300),
        _event(x: 25, y: 0, z: 0, atMs: 400),
        _event(x: 25, y: 0, z: 0, atMs: 500), // still within 1500ms cooldown
      ];
      var shakeCount = 0;
      final service = MotionActionsService(streamFactory: () => Stream.fromIterable(events));

      service.start(onFaceDown: () {}, onFaceUp: () {}, onShake: () => shakeCount++);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(shakeCount, 1);
      service.stop();
    });

    test('fires again for a new shake once the cooldown has elapsed', () async {
      final events = <AccelerometerEvent>[
        _event(x: 25, y: 0, z: 0, atMs: 0),
        _event(x: 25, y: 0, z: 0, atMs: 100),
        _event(x: 25, y: 0, z: 0, atMs: 200), // fires here
        _event(x: 25, y: 0, z: 0, atMs: 2000), // cooldown elapsed
        _event(x: 25, y: 0, z: 0, atMs: 2100),
        _event(x: 25, y: 0, z: 0, atMs: 2200), // fires again
      ];
      var shakeCount = 0;
      final service = MotionActionsService(streamFactory: () => Stream.fromIterable(events));

      service.start(onFaceDown: () {}, onFaceUp: () {}, onShake: () => shakeCount++);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(shakeCount, 2);
      service.stop();
    });
  });

  test('stop() cancels the subscription so no further callbacks fire', () async {
    final controller = StreamController<AccelerometerEvent>();
    var shakeCount = 0;
    final service = MotionActionsService(streamFactory: () => controller.stream);

    service.start(onFaceDown: () {}, onFaceUp: () {}, onShake: () => shakeCount++);
    service.stop();

    controller.add(_event(x: 25, y: 0, z: 0, atMs: 0));
    controller.add(_event(x: 25, y: 0, z: 0, atMs: 100));
    controller.add(_event(x: 25, y: 0, z: 0, atMs: 200));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(shakeCount, 0);
    await controller.close();
  });
}
