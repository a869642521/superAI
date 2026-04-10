import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';

class UserAvatar extends StatelessWidget {
  final UserBrief user;
  final double size;

  /// When true, ignore [user.avatarUrl] and show a varied portrait from DiceBear
  /// (deterministic per [user.id], stable across rebuilds).
  final bool useRandomAvatar;

  const UserAvatar({
    super.key,
    required this.user,
    this.size = 24,
    this.useRandomAvatar = false,
  });

  String? get _effectiveUrl {
    if (useRandomAvatar) {
      final seed = Uri.encodeComponent('${user.id}|${user.nickname}');
      return 'https://api.dicebear.com/7.x/notionists/png?seed=$seed&size=128';
    }
    final u = user.avatarUrl;
    if (u != null && u.isNotEmpty) return u;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = _effectiveUrl;
    if (url != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
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
