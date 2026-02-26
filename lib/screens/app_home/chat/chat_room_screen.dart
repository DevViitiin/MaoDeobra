// lib/screens/chat_room_screen.dart

import 'package:dartobra_new/controllers/chat_controller.dart';
import 'package:dartobra_new/helpers/badge_helper.dart';
import 'package:dartobra_new/screens/app_home/complaints/complaint_chat.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dartobra_new/widgets/message_bubble.dart';
import 'package:dartobra_new/core/utils/date_utils.dart';
import 'package:dartobra_new/models/chat_model/message_model.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final String contractorId;
  final String employeeId;
  final String userRole;
  final String userId;
  final String otherUserName;
  final String? otherUserAvatar;

  const ChatRoomScreen({
    Key? key,
    required this.chatId,
    required this.contractorId,
    required this.employeeId,
    required this.userId,
    required this.userRole,
    required this.otherUserName,
    this.otherUserAvatar,
  }) : super(key: key);

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  bool _isLoadingMore = false;
  bool _hasMarkedAsRead = false;

  @override
  void initState() {
    super.initState();
    debugPrint('═══════════════════════════════════════');
    debugPrint('🎬 CHAT ROOM - INIT');
    debugPrint('═══════════════════════════════════════');
    debugPrint('ChatId: ${widget.chatId}');
    debugPrint('UserId: ${widget.userId}');
    debugPrint('UserRole: ${widget.userRole}');
    
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
      _setupScrollListener();
      _markAsReadWithDelay();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    debugPrint('📱 App Lifecycle: $state');
    
    if (state == AppLifecycleState.resumed && mounted) {
      debugPrint('✅ App resumed - marcando como lido novamente');
      _markAsRead();
    } else if (state == AppLifecycleState.paused) {
      debugPrint('⏸️ App paused');
    }
  }

  /// Marca chat como lido com um pequeno delay para garantir que tudo foi carregado
  Future<void> _markAsReadWithDelay() async {
    if (_hasMarkedAsRead) {
      debugPrint('⚠️ Já foi marcado como lido, pulando...');
      return;
    }

    debugPrint('⏳ Aguardando 500ms antes de marcar como lido...');
    await Future.delayed(Duration(milliseconds: 500));
    
    if (mounted) {
      await _markAsRead();
      _hasMarkedAsRead = true;
    }
  }

  /// Marca o chat como lido e ajusta os badges
  Future<void> _markAsRead() async {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('📖 MARCANDO CHAT COMO LIDO NO CHAT ROOM');
      debugPrint('═══════════════════════════════════════');
      debugPrint('ChatId: ${widget.chatId}');
      debugPrint('UserId: ${widget.userId}');
      debugPrint('UserRole: ${widget.userRole}');
      
      await BadgeHelper.markChatAsRead(
        widget.chatId,
        widget.userId,
        widget.userRole,
      );
      
      debugPrint('✅ Chat marcado como lido com sucesso');
      debugPrint('═══════════════════════════════════════\n');
    } catch (e, stack) {
      debugPrint('❌ ERRO ao marcar chat como lido: $e');
      debugPrint('Stack: $stack');
    }
  }

  Future<void> _initializeChat() async {
    if (!mounted) return;

    debugPrint('🔄 Inicializando chat...');
    
    final controller = context.read<ChatControllerFinal>();
    await controller.initializeChat(
      chatId: widget.chatId,
      contractorId: widget.contractorId,
      employeeId: widget.employeeId,
      userRole: widget.userRole,
    );

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animated: false);
      });
    }
    
    debugPrint('✅ Chat inicializado');
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!mounted) return;

      final isAtBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100;

      if (_showScrollToBottom != !isAtBottom) {
        setState(() {
          _showScrollToBottom = !isAtBottom;
        });
      }

      if (_scrollController.position.pixels <= 100 && !_isLoadingMore) {
        _isLoadingMore = true;

        Future.microtask(() {
          if (mounted) {
            final controller = context.read<ChatControllerFinal>();
            controller.loadMoreMessages().then((_) {
              _isLoadingMore = false;
            });
          }
        });
      }
    });
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;

    if (animated) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    debugPrint('═══════════════════════════════════════');
    debugPrint('👋 CHAT ROOM - DISPOSE');
    debugPrint('═══════════════════════════════════════');
    debugPrint('ChatId: ${widget.chatId}');
    debugPrint('UserId: ${widget.userId}');
    
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    
    try {
      context.read<ChatControllerFinal>().leaveChat();
      debugPrint('✅ Chat fechado com sucesso');
    } catch (e) {
      debugPrint('❌ Erro ao sair do chat: $e');
    }
    
    debugPrint('═══════════════════════════════════════\n');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Consumer<ChatControllerFinal>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (controller.error != null) {
            return _buildErrorWidget(controller.error!);
          }

          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    _buildMessagesList(controller),
                    if (_showScrollToBottom) _buildScrollToBottomButton(),
                  ],
                ),
              ),
              
              ChatInput(
                onSendMessage: (text) async {
                  debugPrint('📤 Enviando mensagem: $text');
                  await controller.sendMessage(text);
                  
                  Future.microtask(() {
                    if (mounted) {
                      _scrollToBottom();
                    }
                  });
                },
                isEnabled: !controller.isSending,
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      titleSpacing: 0,
      title: Consumer<ChatControllerFinal>(
        builder: (context, controller, child) {
          final status = controller.otherParticipantStatus;

          return Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[300],
                backgroundImage: widget.otherUserAvatar != null
                    ? NetworkImage(widget.otherUserAvatar!)
                    : null,
                child: widget.otherUserAvatar == null
                    ? Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUserName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (status != null)
                      AnimatedOnlineStatusIndicator(
                        participant: status,
                        showText: true,
                        size: 8,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_sweep, size: 20),
                  SizedBox(width: 8),
                  Text('Limpar conversa'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'denunciar',
              child: Row(
                children: [
                  Icon(Icons.warning, size: 20),
                  SizedBox(width: 8),
                  Text('Denunciar'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessagesList(ChatControllerFinal controller) {
    if (controller.messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: 16),
      itemCount: controller.messages.length + (controller.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (controller.isLoadingMore && index == 0) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final messageIndex = controller.isLoadingMore ? index - 1 : index;
        final message = controller.messages[messageIndex];
        final isSentByMe = controller.isSentByMe(message);

        Widget? dateSeparator;
        if (messageIndex == 0 ||
            _shouldShowDateSeparator(
              controller.messages[messageIndex - 1].timestamp,
              message.timestamp,
            )) {
          dateSeparator = _buildDateSeparator(message.timestamp);
        }

        return Column(
          children: [
            if (dateSeparator != null) dateSeparator,
            AnimatedMessageBubble(
              message: message,
              isSentByMe: isSentByMe,
              avatarUrl: isSentByMe ? null : widget.otherUserAvatar,
              onLongPress: () => _showMessageOptions(message, isSentByMe),
            ),
          ],
        );
      },
    );
  }

  bool _shouldShowDateSeparator(int prevTimestamp, int currentTimestamp) {
    final prevDate = DateTime.fromMillisecondsSinceEpoch(prevTimestamp);
    final currentDate = DateTime.fromMillisecondsSinceEpoch(currentTimestamp);

    return prevDate.day != currentDate.day ||
        prevDate.month != currentDate.month ||
        prevDate.year != currentDate.year;
  }

  Widget _buildDateSeparator(int timestamp) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            ChatDateUtils.getDateSeparator(timestamp),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text(
            'Nenhuma mensagem ainda',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 8),
          Text(
            'Envie a primeira mensagem!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToBottomButton() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: FloatingActionButton.small(
        onPressed: () => _scrollToBottom(),
        backgroundColor: Theme.of(context).primaryColor,
        child: Icon(Icons.arrow_downward, color: Colors.white),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _hasMarkedAsRead = false;
                _initializeChat();
              },
              child: Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(Message message, bool isSentByMe) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.copy),
              title: Text('Copiar'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            if (isSentByMe)
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Deletar', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(message.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Deletar mensagem'),
        content: Text('Tem certeza que deseja deletar esta mensagem?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Deletar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'clear':
        _confirmClearChat();
        break;
      case 'denunciar':
        late String reportedId = '';

        if (widget.userRole == 'employee') {
          reportedId = widget.contractorId;
        } else {
          reportedId = widget.employeeId;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ComplaintChat(
              chatId: widget.chatId,
              reportId: widget.userId,
              reportedId: reportedId,
            ),
          ),
        );

        break;
    }
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Limpar conversa'),
        content: Text('Todas as mensagens serão apagadas. Continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Limpar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}