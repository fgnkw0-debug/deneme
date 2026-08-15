class UserProfile {
  final String id;
  final String email;
  final String membershipType;
  final int dailyLimit;
  final int usedToday;
  final bool isAdmin;
  final bool isActive;
  final bool canViewCoupons;

  UserProfile({
    required this.id,
    required this.email,
    required this.membershipType,
    required this.dailyLimit,
    required this.usedToday,
    required this.isAdmin,
    required this.isActive,
    required this.canViewCoupons,
  });

  int get remaining => isAdmin ? -1 : (dailyLimit - usedToday).clamp(0, dailyLimit);

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'],
        email: json['email'],
        membershipType: json['membership_type'] ?? 'free',
        dailyLimit: json['daily_limit'] ?? 5,
        usedToday: json['used_today'] ?? 0,
        isAdmin: json['is_admin'] ?? false,
        isActive: json['is_active'] ?? true,
        canViewCoupons: json['can_view_coupons'] ?? false,
      );
}
