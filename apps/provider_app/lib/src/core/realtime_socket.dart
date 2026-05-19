import 'package:socket_io_client/socket_io_client.dart' as io;

class RealtimeSocket {
  RealtimeSocket({required this.baseUrl});

  final String baseUrl;
  io.Socket? _socket;

  bool get connected => _socket?.connected ?? false;

  void connect(String accessToken) {
    _socket?.dispose();
    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .disableAutoConnect()
          .build(),
    );
    _socket!.connect();
  }

  void joinBooking(String bookingId) {
    _socket?.emit('booking.join_room', {'bookingId': bookingId});
  }

  void updateLocation({required double lat, required double lng, String? bookingId}) {
    _socket?.emit('provider.location.update', {
      if (bookingId != null) 'bookingId': bookingId,
      'lat': lat,
      'lng': lng,
    });
  }

  void onEvent(String event, void Function(dynamic payload) handler) {
    _socket?.on(event, handler);
  }

  void offEvent(String event) {
    _socket?.off(event);
  }

  void dispose() {
    _socket?.dispose();
  }
}
