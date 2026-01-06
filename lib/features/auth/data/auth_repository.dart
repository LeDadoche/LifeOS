import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  final GoTrueClient _authClient;

  AuthRepository(this._authClient);

  User? get currentUser => _authClient.currentUser;

  Stream<AuthState> authStateChanges() => _authClient.onAuthStateChange;

  Future<void> signIn(String email, String password) async {
    await _authClient.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password) async {
    await _authClient.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _authClient.signOut();
  }
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository(Supabase.instance.client.auth);
}

@riverpod
Stream<User?> authState(AuthStateRef ref) {
  return ref.watch(authRepositoryProvider).authStateChanges().map((event) => event.session?.user);
}
