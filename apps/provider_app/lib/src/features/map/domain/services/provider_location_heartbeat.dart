import 'dart:async';

class ProviderLocationHeartbeat {
  ProviderLocationHeartbeat(this._updateLocation);

  final Future<void> Function() _updateLocation;
  Timer? _timer;

  Future<void> start({bool runImmediately = true}) async {
    _timer?.cancel();
    if (runImmediately) {
      await _updateLocation();
    }
    _timer = Timer.periodic(const Duration(minutes: 10), (_) {
      unawaited(_updateLocation());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();
}
