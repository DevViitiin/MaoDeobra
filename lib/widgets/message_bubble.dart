// ========================================
// lib/widgets/message_bubble.dart
// ========================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dartobra_new/models/chat_model/message_model.dart';
import 'package:dartobra_new/core/utils/date_utils.dart';

class AnimatedMessageBubble extends StatefulWidget {
  final Message message;
  final bool isSentByMe;
  final String? avatarUrl;
  final VoidCallback? onLongPress;

  const AnimatedMessageBubble({
    Key? key,
    required this.message,
    required this.isSentByMe,
    this.avatarUrl,
    this.onLongPress,
  }) : super(key: key);

  @override
  State<AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.isSentByMe ? Offset(0.3, 0) : Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _buildMessageContent(),
      ),
    );
  }

  Widget _buildMessageContent() {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment: widget.isSentByMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Avatar (apenas para mensagens recebidas)
            if (!widget.isSentByMe) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[300],
                backgroundImage: widget.avatarUrl != null
                    ? NetworkImage(widget.avatarUrl!)
                    : null,
                child: widget.avatarUrl == null
                    ? Icon(Icons.person, size: 16, color: Colors.white)
                    : null,
              ),
              SizedBox(width: 8),
            ],

            // Balão da mensagem
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.isSentByMe
                      ? Theme.of(context).primaryColor
                      : Colors.grey[200],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(widget.isSentByMe ? 18 : 4),
                    bottomRight: Radius.circular(widget.isSentByMe ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Texto da mensagem
                    Text(
                      widget.message.text,
                      style: TextStyle(
                        fontSize: 15,
                        color: widget.isSentByMe ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    
                    // Hora + Status de leitura
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ChatDateUtils.formatMessageTime(widget.message.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: widget.isSentByMe
                                ? Colors.white.withOpacity(0.7)
                                : Colors.grey[600],
                          ),
                        ),
                        if (widget.isSentByMe) ...[
                          SizedBox(width: 4),
                          Icon(
                            widget.message.readByContractor && widget.message.readByEmployee
                                ? Icons.done_all
                                : Icons.done,
                            size: 14,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================
// lib/widgets/chat_input.dart
// ========================================

class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function(bool)? onTypingChanged;
  final bool isEnabled;

  const ChatInput({
    Key? key,
    required this.onSendMessage,
    this.onTypingChanged,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (_hasText != hasText) {
      setState(() {
        _hasText = hasText;
      });
      
      // Notifica typing
      widget.onTypingChanged?.call(hasText);
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && widget.isEnabled) {
      widget.onSendMessage(text);
      _controller.clear();
      widget.onTypingChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Campo de texto
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.isEnabled,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Digite uma mensagem...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            
            SizedBox(width: 8),
            
            // Botão de enviar
            AnimatedScale(
              scale: _hasText ? 1.0 : 0.8,
              duration: Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  color: _hasText && widget.isEnabled
                      ? Theme.of(context).primaryColor
                      : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _hasText && widget.isEnabled ? _sendMessage : null,
                  icon: Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================
// lib/widgets/online_status_indicator.dart
// ========================================

class OnlineStatusBadge extends StatelessWidget {
  final bool isOnline;
  final Widget child;

  const OnlineStatusBadge({
    Key? key,
    required this.isOnline,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class AnimatedOnlineStatusIndicator extends StatelessWidget {
  final dynamic participant; // ParticipantData
  final bool showText;
  final double size;

  const AnimatedOnlineStatusIndicator({
    Key? key,
    required this.participant,
    this.showText = true,
    this.size = 8,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isOnline = participant.isOnline;
    final lastSeen = participant.lastSeen;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bolinha de status
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isOnline ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        
        if (showText) ...[
          SizedBox(width: 6),
          Text(
            ChatDateUtils.formatLastSeen(lastSeen, isOnline),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
}

// ========================================
// Widget: TypingIndicator
// ========================================

class TypingIndicator extends StatefulWidget {
  final Color color;
  final double size;

  const TypingIndicator({
    Key? key,
    required this.color,
    this.size = 6,
  }) : super(key: key);

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final value = (_controller.value - delay) % 1.0;
            final opacity = value < 0.5
                ? value * 2
                : 2 - (value * 2);
            
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity.clamp(0.3, 1.0),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
