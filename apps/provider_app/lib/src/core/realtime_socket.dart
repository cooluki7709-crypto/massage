import 'package:socket_io_client/socket_io_client.dart' as io;

class RealtimeSocket {
  RealtimeSocket({required this.baseUrl});

  final String baseUrl;
  io.Socket? _socket;

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

  void dispose() {
    _socket?.dispose();
  }
}

