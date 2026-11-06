import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:visit_flutter_sdk/src/health_call_guard.dart';

void main() {
  test(
    'duplicate pending handlers perform one native read and JS update',
    () async {
      final guard = HealthCallGuard();
      final response = Completer<String>();
      var reads = 0;
      final updates = <String>[];
      Future<void> handle() => guard.run('dashboard', (document) async {
        reads++;
        final data = await response.future;
        if (guard.isCurrent(document)) updates.add(data);
      });
      final first = handle();
      await Future.wait(List.generate(10, (_) => handle()));
      expect(reads, 1);
      response.complete('today');
      await first;
      expect(updates, ['today']);
      await handle();
      expect(reads, 2);
      expect(updates, ['today', 'today']);
    },
  );

  test(
    'different graph arguments remain independent with reversed results',
    () async {
      final guard = HealthCallGuard();
      final keys = [
        ('steps', 'day', 1),
        ('steps', 'week', 1),
        ('steps', 'day', 2),
        ('sleep', 'day', 1),
      ];
      final responses = {for (final key in keys) key: Completer<String>()};
      final updates = <String>[];
      final work = [
        for (final key in keys)
          guard.run(key, (_) async {
            updates.add(await responses[key]!.future);
          }),
      ];
      for (final key in keys.reversed) {
        responses[key]!.complete(key.toString());
      }
      await Future.wait(work);
      expect(updates, keys.reversed.map((key) => key.toString()));
    },
  );

  test('failures clear the guard and allow retry', () async {
    final guard = HealthCallGuard();
    await expectLater(
      guard.run('data', (_) async => throw StateError('failed')),
      throwsStateError,
    );
    var retried = false;
    await guard.run('data', (_) async {
      retried = true;
    });
    expect(retried, isTrue);
  });

  test('guard covers chained status and dashboard handlers', () async {
    final guard = HealthCallGuard();
    final status = Completer<void>();
    final dashboard = Completer<void>();
    var reads = 0;
    Future<void> handle() => guard.run('status', (_) async {
      reads++;
      await status.future;
      await guard.run('dashboard', (_) => dashboard.future);
    });
    final first = handle();
    status.complete();
    await Future<void>.delayed(Duration.zero);
    await handle();
    expect(reads, 1);
    dashboard.complete();
    await first;
  });

  test('late old work cannot update or clear a new document request', () async {
    final guard = HealthCallGuard();
    final old = Completer<void>();
    final current = Completer<void>();
    final updates = <String>[];
    final first = guard.run('data', (document) async {
      await old.future;
      if (guard.isCurrent(document)) updates.add('old');
    });
    guard.newDocument();
    final second = guard.run('data', (document) async {
      await current.future;
      if (guard.isCurrent(document)) updates.add('new');
    });
    old.complete();
    await first;
    var duplicateRan = false;
    await guard.run('data', (_) async {
      duplicateRan = true;
    });
    expect(duplicateRan, isFalse);
    current.complete();
    await second;
    expect(updates, ['new']);
  });

  test('disposal suppresses late effects and future handlers', () async {
    final guard = HealthCallGuard();
    final response = Completer<void>();
    var effects = 0;
    final first = guard.run('data', (document) async {
      await response.future;
      if (guard.isCurrent(document)) effects++;
    });
    guard.dispose();
    response.complete();
    await first;
    await guard.run('other', (_) async {
      effects++;
    });
    expect(effects, 0);
  });

  test(
    'reentrant duplicate handlers are suppressed before any await',
    () async {
      final guard = HealthCallGuard();
      var calls = 0;
      await guard.run('permission', (_) async {
        calls++;
        await guard.run('permission', (_) async {
          calls++;
        });
      });
      expect(calls, 1);
    },
  );
}
