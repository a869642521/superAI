import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';

class UserAvatar extends StatelessWidget {
  final UserBrief user;
  final double size;

  const UserAvatar({super.key, required this.user, this.size = 24});

  @override
  Widget build(BuildContext context) {
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: user.avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: StarpathColors.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          user.nickname.isNotEmpty ? user.nickname[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: size * 0.5,
            color: StarpathColors.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
