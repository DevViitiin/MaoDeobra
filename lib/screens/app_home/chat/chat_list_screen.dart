// lib/screens/chat_list_screen.dart

// ignore_for_file: unused_field

import 'package:dartobra_new/controllers/chat_controller.dart';
import 'package:dartobra_new/core/utils/date_utils.dart';
import 'package:dartobra_new/models/chat_model/chat_model.dart';
import 'package:dartobra_new/services/services_chat/chat_service.dart';
import 'package:dartobra_new/services/services_chat/firebase_service.dart';
import 'package:dartobra_new/services/services_chat/user_lockup.service.dart';
import 'package:dartobra_new/widgets/online_status_indicator.dart';
import 'package:dartobra_new/helpers/badge_helper.dart';
import 'package:flutter/material.dart';
import 'chat_room_screen.dart';
import 'package:provider/provider.dart';

class ChatListScreen extends StatefulWidget {
  final String userId;
  final String userRole;

  const ChatListScreen({
    Key? key,
    required this.userId,
    required this.userRole,
  }) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  final ChatServiceFinal _chatService = ChatServiceFinal();
  final FirebaseService _firebase = FirebaseService();
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Mensagens',
          style: TextStyle(color: Colors.black87),
        ),
        iconTheme: IconThemeData(color: Colors.black87),
        actions: [
          // Badge indicator TOTAL
          StreamBuilder<BadgeData>(
            stream: BadgeHelper.getBadgeStream(widget.userId),
            builder: (context, snapshot) {
              final badgeData = snapshot.data;
              if (badgeData == null || badgeData.unreadChats == 0) {
                return SizedBox.shrink();
              }

              return Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${badgeData.unreadChats}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Connection status
          StreamBuilder<bool>(
            stream: _firebase.connectionState,
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? false;
              return Padding(
                padding: EdgeInsets.only(right: 16),
                child: Icon(
                  isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: isConnected ? Colors.green : Colors.red,
                  size: 20,
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: [
            // Tab CONTRACTOR com badge
            StreamBuilder<int>(
              stream: BadgeHelper.getUnreadCountByRoleStream(
                widget.userId,
                'contractor',
              ),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.work_outline, size: 20),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Contratante',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            
            // Tab EMPLOYEE com badge
            StreamBuilder<int>(
              stream: BadgeHelper.getUnreadCountByRoleStream(
                widget.userId,
                'employee',
              ),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_outline, size: 20),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Funcionário',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Chats como CONTRATANTE
          _ChatListTab(
            key: ValueKey('contractor'),
            userId: widget.userId,
            roleFilter: 'contractor',
            onOpenChat: _openChat,
          ),
          
          // Tab 2: Chats como FUNCIONÁRIO
          _ChatListTab(
            key: ValueKey('employee'),
            userId: widget.userId,
            roleFilter: 'employee',
            onOpenChat: _openChat,
          ),
        ],
      ),
    );
  }

  void _openChat(Chat chat, String roleFilter) async {
    final isContractor = roleFilter == 'contractor';
    final otherUserId = isContractor ? chat.employeeId : chat.contractorId;

    try {
      final userLookup = UserLookupService();
      final otherUserData = await userLookup.getUserData(otherUserId);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider(
            create: (_) => ChatControllerFinal(),
            child: ChatRoomScreen(
              chatId: chat.chatId,
              contractorId: chat.contractorId,
              employeeId: chat.employeeId,
              userRole: roleFilter,
              userId: widget.userId,
              otherUserName: otherUserData.name,
              otherUserAvatar: otherUserData.avatar.isNotEmpty
                  ? otherUserData.avatar
                  : null,
            ),
          ),
        ),
      );
    } catch (e) {
      print('❌ Erro ao abrir chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir conversa. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ✅ Widget separado para cada tab - evita conflito de streams
class _ChatListTab extends StatelessWidget {
  final String userId;
  final String roleFilter;
  final Function(Chat, String) onOpenChat;

  const _ChatListTab({
    Key? key,
    required this.userId,
    required this.roleFilter,
    required this.onOpenChat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final chatService = ChatServiceFinal();

    return StreamBuilder<List<Chat>>(
      stream: chatService.getChatListStream(userId, roleFilter),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('❌ Erro no stream de chats: ${snapshot.error}');
          return _buildErrorWidget(context, snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Carregando conversas...',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final chats = snapshot.data ?? [];

        if (chats.isEmpty) {
          return _buildEmptyState(context, roleFilter);
        }

        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(Duration(milliseconds: 500));
          },
          child: ListView.separated(
            padding: EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 72,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _ChatListTile(
                key: ValueKey(chat.chatId),
                chat: chat,
                currentUserId: userId,
                userRole: roleFilter,
                onTap: () => onOpenChat(chat, roleFilter),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String role) {
    final isContractor = role == 'contractor';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isContractor ? Icons.work_outline : Icons.person_outline,
            size: 80,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16),
          Text(
            'Nenhuma conversa ainda',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              isContractor
                  ? 'Suas conversas como contratante aparecerão aqui'
                  : 'Suas conversas como funcionário aparecerão aqui',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              'Erro ao carregar conversas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ WIDGET OTIMIZADO - StatelessWidget para evitar problemas de stream
class _ChatListTile extends StatelessWidget {
  final Chat chat;
  final String currentUserId;
  final String userRole;
  final VoidCallback onTap;

  const _ChatListTile({
    Key? key,
    required this.chat,
    required this.currentUserId,
    required this.userRole,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isContractor = userRole == 'contractor';
    final otherUserId = isContractor ? chat.employeeId : chat.contractorId;
    final otherRole = isContractor ? 'employee' : 'contractor';

    final otherParticipant = chat.participants[otherRole];

    if (otherParticipant == null) {
      print('⚠️ Participante não encontrado para role: $otherRole no chat: ${chat.chatId}');
      return SizedBox.shrink();
    }

    return Container(
      color: Colors.white,
      child: StreamBuilder<UserData>(
        stream: UserLookupService().getUserDataStream(otherUserId),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            print('❌ Erro ao carregar usuário $otherUserId: ${userSnapshot.error}');
            return _buildErrorTile(context);
          }

          final userData = userSnapshot.data ??
              UserData(
                name: 'Usuário',
                avatar: '',
                profession: '',
              );

          // ✅ Stream do unreadCount
          return StreamBuilder<int>(
            stream: ChatServiceFinal().getUnreadCountStream(chat.chatId, userRole),
            initialData: 0,
            builder: (context, unreadSnapshot) {
              final unreadCount = unreadSnapshot.data ?? 0;

              return Material(
                color: Colors.white,
                child: InkWell(
                  onTap: onTap,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Avatar com status online
                        OnlineStatusBadge(
                          isOnline: otherParticipant.isOnline,
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: userData.avatar.isNotEmpty
                                ? NetworkImage(userData.avatar)
                                : null,
                            child: userData.avatar.isEmpty
                                ? Icon(Icons.person,
                                    color: Colors.white, size: 28)
                                : null,
                          ),
                        ),
                        SizedBox(width: 12),

                        // Conteúdo do chat
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nome e horário
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      userData.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: unreadCount > 0
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    _formatTime(chat.metadata.lastTimestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),

                              // Última mensagem e badge
                              Row(
                                children: [
                                  if (chat.metadata.lastSender == userRole)
                                    Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Icon(
                                        Icons.done_all,
                                        size: 16,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      chat.metadata.lastMessage.isEmpty
                                          ? 'Nenhuma mensagem ainda'
                                          : chat.metadata.lastMessage,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: unreadCount > 0
                                            ? Colors.black87
                                            : Colors.grey[600],
                                        fontWeight: unreadCount > 0
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (unreadCount > 0) ...[
                                    SizedBox(width: 8),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        unreadCount > 99
                                            ? '99+'
                                            : '$unreadCount',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorTile(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[300],
            child: Icon(Icons.error_outline, color: Colors.red),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Erro ao carregar conversa',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int timestamp) {
    try {
      return ChatDateUtils.formatChatListTime(timestamp);
    } catch (e) {
      print('❌ Erro ao formatar timestamp: $e');
      return '';
    }
  }
}