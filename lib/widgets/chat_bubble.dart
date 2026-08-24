import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'glass_container.dart';

class ChatMessage {
  final String text;
  final bool fromUser;
  final DateTime time;

  ChatMessage(this.text, {required this.fromUser, DateTime? time}) : time = time ?? DateTime.now();
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    final colorScheme = Theme.of(context).colorScheme;

    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(28),
      topRight: const Radius.circular(28),
      bottomLeft: Radius.circular(isUser ? 28 : 10),
      bottomRight: Radius.circular(isUser ? 10 : 28),
    );

    final text = Text(
      message.text,
      style: TextStyle(
        color: isUser ? colorScheme.onPrimary : colorScheme.onSurface.withValues(alpha: 0.92),
        fontSize: 15,
        height: 1.4,
        fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
      ),
    );

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.78 : 0.85)),
      child: isUser
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: bubbleRadius,
                boxShadow: [
                  BoxShadow(color: colorScheme.primary.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 8)),
                ],
              ),
              child: text,
            )
          : GlassContainer(
              borderRadius: bubbleRadius,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6)),
              ],
              child: text,
            ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 12, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'JARVIS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft, child: bubble),
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 4),
              child: Text(
                DateFormat.Hm('de_DE').format(message.time),
                style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
              ),
            ),
        ],
      ),
    );
  }
}
