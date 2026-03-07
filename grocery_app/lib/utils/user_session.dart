class UserSession {
  static UserSession? _current;

  final int id;
  final String name;
  final String role;
  final bool canSell;
  final bool canAddProducts;
  final bool canPurchase;
  final bool canDiscount;
  final bool canViewReports;

  UserSession({
    required this.id,
    required this.name,
    required this.role,
    required this.canSell,
    required this.canAddProducts,
    required this.canPurchase,
    required this.canDiscount,
    required this.canViewReports,
  });

  bool get isAdmin => role == 'admin';

  static UserSession? get current => _current;

  static void login(UserSession session) => _current = session;
  static void logout() => _current = null;
  static void clear() => _current = null; // alias for logout

  factory UserSession.fromMap(Map<String, dynamic> m) => UserSession(
    id: m['id'],
    name: m['name'],
    role: m['role'] ?? 'employee',
    canSell: (m['can_sell'] ?? 1) == 1,
    canAddProducts: (m['can_add_products'] ?? 0) == 1,
    canPurchase: (m['can_purchase'] ?? 0) == 1,
    canDiscount: (m['can_discount'] ?? 0) == 1,
    canViewReports: (m['can_view_reports'] ?? 0) == 1,
  );
}
