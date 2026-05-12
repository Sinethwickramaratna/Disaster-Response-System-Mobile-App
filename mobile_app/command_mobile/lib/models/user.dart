class User {
  final String serviceId;
  final String role;
  final String zone;
  final String? userId;
  final String? email;
  final String? name;

  User({
    required this.serviceId,
    required this.role,
    required this.zone,
    this.userId,
    this.email,
    this.name,
  });
}
