import 'package:flutter_test/flutter_test.dart';
import 'package:command_mobile/services/auth_service.dart';

void main() {
  setUp(AuthService.signOut);

  group('AuthService', () {
    test('successful login stores current user', () {
      final user = AuthService.authenticate('CMD-049', 'command123');

      expect(user, isNotNull);
      expect(user!.serviceId, 'CMD-049');
      expect(user.role, 'OFFICER');
      expect(user.zone, 'ZONE-A');
      expect(AuthService.currentUser, same(user));
    });

    test('login normalizes service id case and whitespace', () {
      final user = AuthService.authenticate('  fo-a01 ', 'zonea001');

      expect(user, isNotNull);
      expect(user!.serviceId, 'FO-A01');
      expect(user.zone, 'ZONE-A');
    });

    test('wrong password fails and does not create a session', () {
      final user = AuthService.authenticate('CMD-049', 'wrong-password');

      expect(user, isNull);
      expect(AuthService.currentUser, isNull);
    });

    test('empty fields fail', () {
      expect(AuthService.authenticate('', ''), isNull);
      expect(AuthService.authenticate('CMD-049', ''), isNull);
      expect(AuthService.authenticate('', 'command123'), isNull);
      expect(AuthService.currentUser, isNull);
    });

    test('invalid service id fails', () {
      final user = AuthService.authenticate('bad-email@example.com', 'command123');

      expect(user, isNull);
      expect(AuthService.currentUser, isNull);
    });

    test('logout clears current user', () {
      AuthService.authenticate('LOG-012', 'logistics123');
      expect(AuthService.currentUser, isNotNull);

      AuthService.signOut();

      expect(AuthService.currentUser, isNull);
    });
  });
}
