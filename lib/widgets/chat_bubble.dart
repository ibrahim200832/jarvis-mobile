import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ChatMessage {
  final String text;
  final bool fromUser;

  ChatMessage(this.text, {required this.fromUser});
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.fromUser;
    final colorScheme = Theme.of(context).colorScheme;

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
      decoration: BoxDecoration(
        color: isUser ? colorScheme.primary : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
      ),
      child: Text(
        message.text,
        style: TextStyle(color: isUser ? colorScheme.onPrimary : colorScheme.onSurface),
      ),
    );

    final avatar = isUser
        ? CircleAvatar(
            radius: 14,
            backgroundColor: colorScheme.secondaryContainer,
            child: Icon(Icons.person, size: 16, color: colorScheme.onSecondaryContainer),
          )
        : ClipOval(
            child: SvgPicture.asset('assets/icon/logo.svg', width: 28, height: 28),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: isUser ? [Flexible(child: bubble), avatar] : [avatar, Flexible(child: bubble)],
      ),
    );
  }
}
