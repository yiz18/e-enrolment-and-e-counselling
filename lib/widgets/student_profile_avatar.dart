import 'package:flutter/material.dart';

import '../services/user_profile_service.dart';

/// Displays the signed-in student's profile photo from `users/{uid}`.
///
/// Subscribes to [UserProfileService.watchCurrentProfile] so the avatar
/// updates automatically when `profileImageUrl` changes in Firestore.
class StudentProfileAvatar extends StatelessWidget {
  const StudentProfileAvatar({
    super.key,
    this.radius = 18,
    this.onTap,
  });

  final double radius;
  final VoidCallback? onTap;

  static final _profileService = UserProfileService();

  @override
  Widget build(BuildContext context) {
    final avatar = StreamBuilder(
      stream: _profileService.watchCurrentProfile(),
      builder: (context, snapshot) {
        final imageUrl = snapshot.data?.profileImageUrl?.trim();
        return _buildAvatar(imageUrl);
      },
    );

    if (onTap == null) return avatar;

    return GestureDetector(
      onTap: onTap,
      child: avatar,
    );
  }

  Widget _buildAvatar(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.blueAccent,
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blueAccent,
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: radius * 1.1,
      ),
    );
  }
}
