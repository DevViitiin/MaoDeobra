// lib/services/chat_service_final.dart - COMPATÍVEL COM FORMATO ANTIGO

// ignore_for_file: unused_field, unnecessary_cast

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../../models/chat_model/chat_model.dart';
import '../../models/chat_model/message_model.dart';
import '../../models/chat_model/participant_model.dart';
import '../../core/constants/firebase_paths.dart';
import 'firebase_service.dart';


class ChatServiceFinal {
  final FirebaseService _firebase = FirebaseService();
  
  static const int INITIAL_MESSAGES_LIMIT = 15;
  
  // Cache local
  final Map<String, List<Message>> _messagesCache = {};
  final Map<String, int> _lastLoadedTimestamp = {};
  final Map<String, StreamSubscription> _activeListeners = {};
  
  String? _activeChat;
  String? _userRole;
  
  static final ChatServiceFinal _instance = ChatServiceFinal._internal();
  factory ChatServiceFinal() => _instance;
  ChatServiceFinal._internal();

  // ========================================
  // 1️⃣ INICIALIZAÇÃO DO CHAT
  // ========================================
  
  Future<Chat> initializeChat(
    String chatId,
    String contractorId,
    String employeeId,
    String userRole,
  ) async {
    try {
      final chatSnapshot = await _firebase.getSnapshot(
        FirebasePaths.chatPath(chatId)
      );

      Chat chat;
      
      if (chatSnapshot == null) {
        final initialData = Chat.createInitialStructure(
          contractorId,
          employeeId,
        );
        
        await _firebase.chatRef(chatId).set(initialData);
        await _firebase.ensureChatMessagesStructure(chatId);
        
        chat = Chat.fromMap(chatId, initialData);
      } else {
        chat = Chat.fromMap(
          chatId,
          chatSnapshot.value as Map<dynamic, dynamic>,
        );
        
        await _firebase.ensureChatMessagesStructure(chatId);
      }

      return chat;
      
    } catch (e) {
      throw Exception('Erro ao inicializar chat: $e');
    }
  }

  // ========================================
  // 2️⃣ STATUS ONLINE/OFFLINE - COMPATÍVEL COM FORMATO ANTIGO
  // ========================================
  
  /// ✅ ATUALIZADO: Usa formato flat (antigo) que está no seu banco
  Future<void> setUserOnline(String chatId, String userRole) async {
    try {
      _activeChat = chatId;
      _userRole = userRole;
      
      // ✅ Usa formato FLAT (compatível com estrutura atual)
      final statusPath = 'Chats/$chatId/participants/$userRole';
      final lastSeenPath = 'Chats/$chatId/participants/${userRole}_last_seen';
      final now = ServerValue.timestamp;

      await _firebase.updateMultiplePaths({
        statusPath: 'online',
        lastSeenPath: now,
      });

      _firebase.setOnDisconnect(statusPath, 'offline');
      _firebase.setOnDisconnect(lastSeenPath, now);

      print('✅ Status online configurado (formato flat)');
      
    } catch (e) {
      print('❌ Erro ao marcar online: $e');
    }
  }

  /// ✅ ATUALIZADO: Usa formato flat (antigo)
  Future<void> setUserOffline(String chatId, String userRole) async {
    try {
      final statusPath = 'Chats/$chatId/participants/$userRole';
      final lastSeenPath = 'Chats/$chatId/participants/${userRole}_last_seen';

      await _firebase.updateMultiplePaths({
        statusPath: 'offline',
        lastSeenPath: ServerValue.timestamp,
      });

      await _firebase.cancelOnDisconnect(statusPath);
      await _firebase.cancelOnDisconnect(lastSeenPath);
      
      _activeChat = null;
      _userRole = null;
      
      print('✅ Status offline definido (formato flat)');
      
    } catch (e) {
      print('❌ Erro ao marcar offline: $e');
    }
  }

  // ========================================
  // 3️⃣ ENVIAR MENSAGEM
  // ========================================
  
  Future<String> sendMessage(
    String chatId,
    String text,
    String senderRole,
  ) async {
    try {
      if (text.trim().isEmpty) {
        throw Exception('Mensagem vazia');
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final messagesRef = _firebase.chatMessagesRef(chatId).push();
      final messageId = messagesRef.key!;

      final message = Message(
        id: messageId,
        text: text.trim(),
        sender: senderRole,
        timestamp: now,
        readByContractor: senderRole == 'contractor',
        readByEmployee: senderRole == 'employee',
      );

      await messagesRef.set(message.toMap());

      final recipientRole = senderRole == 'contractor' ? 'employee' : 'contractor';
      await _incrementUnreadCount(chatId, recipientRole);

      await _updateChatMetadata(
        chatId: chatId,
        lastMessage: text.trim(),
        lastSender: senderRole,
        lastTimestamp: now,
      );

      print('✅ Mensagem enviada: $messageId');
      return messageId;
      
    } catch (e) {
      throw Exception('Erro ao enviar mensagem: $e');
    }
  }

  Future<void> _incrementUnreadCount(String chatId, String userRole) async {
    try {
      final countRef = _firebase.database
          .ref('Chats/$chatId/unreadCount/$userRole');
      
      await countRef.runTransaction((current) {
        final currentCount = (current as int?) ?? 0;
        return Transaction.success(currentCount + 1);
      });
      
    } catch (e) {
      print('❌ Erro ao incrementar unreadCount: $e');
    }
  }

  // ========================================
  // 4️⃣ LISTENER DE MENSAGENS
  // ========================================
  
  Stream<List<Message>> getMessagesStream(String chatId) {
    final controller = StreamController<List<Message>>.broadcast();
    
    _loadInitialMessages(chatId, INITIAL_MESSAGES_LIMIT).then((initialMessages) {
      _messagesCache[chatId] = initialMessages;
      controller.add(initialMessages);
      
      if (initialMessages.isNotEmpty) {
        _lastLoadedTimestamp[chatId] = initialMessages.last.timestamp;
      }
      
      _setupIncrementalListener(chatId, controller);
    });
    
    return controller.stream;
  }

  Future<List<Message>> _loadInitialMessages(String chatId, int limit) async {
    try {
      final snapshot = await _firebase
          .chatMessagesRef(chatId)
          .orderByChild('timestamp')
          .limitToLast(limit)
          .get();

      if (!snapshot.exists) return [];

      final data = snapshot.value;
      
      if (data is! Map) {
        print('⚠️ Mensagens não são Map: ${data.runtimeType}');
        return [];
      }

      final messages = <Message>[];

      (data as Map<dynamic, dynamic>).forEach((key, value) {
        if (key == '_placeholder') return;
        
        if (value is Map) {
          try {
            messages.add(Message.fromMap(key, value));
          } catch (e) {
            print('⚠️ Erro ao parsear mensagem $key: $e');
          }
        }
      });

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      print('🔥 ${messages.length} mensagens iniciais carregadas');
      return messages;
      
    } catch (e) {
      print('❌ Erro ao carregar mensagens iniciais: $e');
      return [];
    }
  }

  void _setupIncrementalListener(
    String chatId,
    StreamController<List<Message>> controller,
  ) {
    final lastTimestamp = _lastLoadedTimestamp[chatId] ?? 0;
    
    final listener = _firebase
        .chatMessagesRef(chatId)
        .orderByChild('timestamp')
        .startAfter(lastTimestamp)
        .onChildAdded
        .listen((event) {
      
      if (event.snapshot.key == '_placeholder') return;
      
      final data = event.snapshot.value;
      
      if (data is! Map) {
        print('⚠️ Mensagem recebida não é Map: ${data.runtimeType}');
        return;
      }
      
      try {
        final newMessage = Message.fromMap(event.snapshot.key!, data);
        
        final currentMessages = _messagesCache[chatId] ?? [];
        final isDuplicate = currentMessages.any((m) => m.id == newMessage.id);
        
        if (!isDuplicate) {
          currentMessages.add(newMessage);
          _messagesCache[chatId] = currentMessages;
          _lastLoadedTimestamp[chatId] = newMessage.timestamp;
          
          controller.add(currentMessages);
          print('📨 Nova mensagem adicionada: ${newMessage.id}');
        }
      } catch (e) {
        print('❌ Erro ao processar nova mensagem: $e');
      }
    });
    
    _activeListeners['messages_$chatId'] = listener;
  }

  // ========================================
  // 5️⃣ PAGINAÇÃO
  // ========================================
  
  Future<List<Message>> loadOlderMessages(
    String chatId, {
    required int oldestTimestamp,
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firebase
          .chatMessagesRef(chatId)
          .orderByChild('timestamp')
          .endBefore(oldestTimestamp)
          .limitToLast(limit)
          .get();

      if (!snapshot.exists) return [];

      final data = snapshot.value;
      
      if (data is! Map) {
        print('⚠️ Dados de paginação não são Map');
        return [];
      }

      final messages = <Message>[];

      (data as Map<dynamic, dynamic>).forEach((key, value) {
        if (key == '_placeholder') return;
        if (value is Map) {
          try {
            messages.add(Message.fromMap(key, value));
          } catch (e) {
            print('⚠️ Erro ao parsear mensagem antiga: $e');
          }
        }
      });

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      final cachedMessages = _messagesCache[chatId] ?? [];
      _messagesCache[chatId] = [...messages, ...cachedMessages];
      
      print('🔥 ${messages.length} mensagens antigas carregadas');
      return messages;
      
    } catch (e) {
      print('❌ Erro ao carregar mensagens antigas: $e');
      return [];
    }
  }

  // ========================================
  // 6️⃣ MARK AS READ
  // ========================================
  
  Future<void> markAsRead(String chatId, String userRole) async {
    try {
      final countRef = _firebase.database
          .ref('Chats/$chatId/unreadCount/$userRole');
      
      await countRef.set(0);
      
      print('✅ Chat marcado como lido');
      
    } catch (e) {
      print('❌ Erro ao marcar como lido: $e');
    }
  }

  // ========================================
  // 7️⃣ STATUS DO OUTRO USUÁRIO - COMPATÍVEL COM FORMATO FLAT
  // ========================================
  
  /// ✅ ATUALIZADO: Lê formato flat (antigo)
  Stream<ParticipantData> getOtherParticipantStatus(
    String chatId,
    String myRole,
  ) {
    final otherRole = myRole == 'contractor' ? 'employee' : 'contractor';
    
    return _firebase.database
        .ref('Chats/$chatId/participants')
        .onValue
        .map((event) {
      
      try {
        if (event.snapshot.exists) {
          final data = event.snapshot.value;
          
          if (data is Map) {
            // ✅ Usa ParticipantData.fromMap que já suporta ambos formatos
            final participant = ParticipantData.fromMap(data, otherRole);
            
            print('👤 Status do $otherRole: ${participant.status} (${participant.lastSeen})');
            
            return participant;
          }
        }
      } catch (e) {
        print('❌ Erro ao processar status: $e');
      }
      
      return ParticipantData(
        status: 'offline',
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  // ========================================
  // 8️⃣ UNREAD COUNT
  // ========================================
  
  Stream<int> getUnreadCountStream(String chatId, String userRole) {
    return _firebase.database
        .ref('Chats/$chatId/unreadCount/$userRole')
        .onValue
        .map((event) {
      return (event.snapshot.value as int?) ?? 0;
    });
  }

  // ========================================
  // 9️⃣ METADATA DO CHAT
  // ========================================
  
  Future<void> _updateChatMetadata({
    required String chatId,
    required String lastMessage,
    required String lastSender,
    required int lastTimestamp,
  }) async {
    try {
      final metadataRef = _firebase.chatMetadataRef(chatId);
      
      await metadataRef.update({
        'last_message': lastMessage,
        'last_sender': lastSender,
        'last_timestamp': lastTimestamp,
      });
      
    } catch (e) {
      print('❌ Erro ao atualizar metadata: $e');
    }
  }

  // ========================================
  // 🔟 LISTA DE CHATS - COM TRATAMENTO ROBUSTO
  // ========================================
  
  Stream<List<Chat>> getChatListStream(String userId, String userRole) {
    final field = userRole == 'contractor' ? 'contractor' : 'employee';
    
    return _firebase.database
        .ref('Chats')
        .orderByChild(field)
        .equalTo(userId)
        .onValue
        .map((event) {
      try {
        if (!event.snapshot.exists) {
          print('📋 Nenhum chat encontrado para $userId ($userRole)');
          return <Chat>[];
        }

        final data = event.snapshot.value;
        
        if (data is! Map) {
          print('❌ Dados de chats não são Map: ${data.runtimeType}');
          return <Chat>[];
        }

        final chats = <Chat>[];

        (data as Map<dynamic, dynamic>).forEach((chatId, chatData) {
          if (chatData is Map) {
            try {
              final chat = Chat.fromMap(chatId, chatData);
              chats.add(chat);
              print('✅ Chat carregado: $chatId');
            } catch (e) {
              print('❌ Erro ao parsear chat $chatId: $e');
            }
          } else {
            print('⚠️ Chat $chatId não é Map: ${chatData.runtimeType}');
          }
        });

        chats.sort((a, b) => 
          b.metadata.lastTimestamp.compareTo(a.metadata.lastTimestamp)
        );

        print('📋 Total de chats carregados: ${chats.length}');
        return chats;
        
      } catch (e) {
        print('❌ Erro ao processar lista de chats: $e');
        return <Chat>[];
      }
    });
  }

  // ========================================
  // 🧹 CLEANUP
  // ========================================
  
  void disposeChat() {
    _activeListeners.forEach((key, subscription) {
      subscription.cancel();
    });
    _activeListeners.clear();
    
    _activeChat = null;
    _userRole = null;
    
    print('🧹 Chat listeners cancelados');
  }

  void clearChatCache(String chatId) {
    _messagesCache.remove(chatId);
    _lastLoadedTimestamp.remove(chatId);
  }

  void clearAllCache() {
    _messagesCache.clear();
    _lastLoadedTimestamp.clear();
  }

  void dispose() {
    disposeChat();
    clearAllCache();
  }
}