import 'package:flutter_test/flutter_test.dart';
import 'package:provider_app/src/features/map/domain/services/provider_location_heartbeat.dart';

void main() {
  test('runs an immediate location update by default', () async {
    var calls = 0;
    final heartbeat = ProviderLocationHeartbeat(() async {
      calls += 1;
    });

    await heartbeat.start();
    heartbeat.stop();

    expect(calls, 1);
  });

  test('can start timer without duplicating an already-sent location update',
      () async {
    var calls = 0;
    final heartbeat = ProviderLocationHeartbeat(() async {
      calls += 1;
    });

    await heartbeat.start(runImmediately: false);
    heartbeat.stop();

    expect(calls, 0);
  });
}
