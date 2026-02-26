// lib/core/constants/firebase_paths.dart

class FirebasePaths {
  // Chats principais
  static const String chats = 'Chats';
  static const String chatMessages = 'ChatMessages';
  
  // Subcaminhos do Chat
  static String chatPath(String chatId) => '$chats/$chatId';
  
  static String chatContractor(String chatId) => 
      '${chatPath(chatId)}/contractor';
  
  static String chatEmployee(String chatId) => 
      '${chatPath(chatId)}/employee';
  
  static String chatParticipants(String chatId) => 
      '${chatPath(chatId)}/participants';
  
  static String chatMetadata(String chatId) => 
      '${chatPath(chatId)}/metadata';
  
  // Status de participante específico
  static String participantStatus(String chatId, String role) => 
      '${chatParticipants(chatId)}/$role';
  
  static String participantLastSeen(String chatId, String role) => 
      '${chatParticipants(chatId)}/${role}_last_seen';
  
  // Mensagens
  static String chatMessagesPath(String chatId) => 
      '$chatMessages/$chatId';
  
  static String messagePath(String chatId, String messageId) => 
      '${chatMessagesPath(chatId)}/$messageId';
  
  // Status de leitura
  static String messageReadStatus(
    String chatId, 
    String messageId, 
    String role
  ) => '${messagePath(chatId, messageId)}/read_by_$role';
}

class ChatConstants {
  // Status
  static const String statusOnline = 'online';
  static const String statusOffline = 'offline';
  
  // Roles
  static const String roleContractor = 'contractor';
  static const String roleEmployee = 'employee';
  
  // Heartbeat - ✅ OTIMIZADO
  static const Duration heartbeatInterval = Duration(minutes: 2); // ✅ MUDOU de 30s → 2min
  static const Duration offlineThreshold = Duration(minutes: 5); // ✅ MUDOU de 2min → 5min
  
  // Paginação - ✅ OTIMIZADO
  static const int messagesPageSize = 20; // ✅ MUDOU de 50 → 20
  static const int initialLoadSize = 30; // ✅ Mantém 30 inicial (bom!)
}
