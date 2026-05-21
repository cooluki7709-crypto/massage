abstract class ChatRepository {
  Future<List<dynamic>> listChatMessages(String chatRoomId);

  void joinChat(String chatRoomId);

  void sendChatMessage(String chatRoomId, String text);
}
