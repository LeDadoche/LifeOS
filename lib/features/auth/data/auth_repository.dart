import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_repository.g.dart';

/// Exception personnalisée pour l'authentification avec message en français
class AuthError implements Exception {
  final String message;
  final String? code;

  AuthError(this.message, {this.code});

  /// Mappe les codes d'erreur Supabase en messages français conviviaux
  factory AuthError.fromAuthException(AuthException e) {
    final code = e.code?.toLowerCase() ?? '';
    final message = e.message.toLowerCase();

    // Mapping des erreurs courantes
    if (code.contains('invalid_credentials') ||
        message.contains('invalid login credentials') ||
        message.contains('invalid_credentials')) {
      return AuthError(
        "L'adresse email ou le mot de passe est incorrect.",
        code: 'invalid_credentials',
      );
    }

    if (code.contains('user_not_found') || message.contains('user not found')) {
      return AuthError(
        "Ce compte n'existe pas encore.",
        code: 'user_not_found',
      );
    }

    if (code.contains('email_not_confirmed') ||
        message.contains('email not confirmed')) {
      return AuthError(
        "Ton email n'a pas encore été confirmé. Vérifie ta boîte mail.",
        code: 'email_not_confirmed',
      );
    }

    if (code.contains('user_already_exists') ||
        message.contains('user already registered')) {
      return AuthError(
        "Cette adresse email est déjà utilisée.",
        code: 'user_already_exists',
      );
    }

    if (code.contains('weak_password') || message.contains('weak password')) {
      return AuthError(
        "Ce mot de passe est trop faible. Utilise au moins 6 caractères.",
        code: 'weak_password',
      );
    }

    if (code.contains('too_many_requests') ||
        message.contains('too many requests') ||
        message.contains('rate limit')) {
      return AuthError(
        "Trop de tentatives. Attends un peu avant de réessayer.",
        code: 'too_many_requests',
      );
    }

    // Erreur par défaut
    return AuthError(
      "Oups, une petite erreur est survenue. Réessaye dans un instant.",
      code: code.isNotEmpty ? code : null,
    );
  }

  /// Mappe les erreurs réseau
  factory AuthError.networkError() {
    return AuthError(
      "Problème de connexion internet. Vérifie ton réseau.",
      code: 'network_error',
    );
  }

  @override
  String toString() => message;
}

class AuthRepository {
  final GoTrueClient _authClient;

  AuthRepository(this._authClient);

  User? get currentUser => _authClient.currentUser;

  Stream<AuthState> authStateChanges() => _authClient.onAuthStateChange;

  Future<void> signIn(String email, String password) async {
    try {
      await _authClient.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw AuthError.fromAuthException(e);
    } catch (e) {
      // Erreur réseau ou autre
      if (e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('socket') ||
          e.toString().toLowerCase().contains('connection')) {
        throw AuthError.networkError();
      }
      throw AuthError(
          "Oups, une petite erreur est survenue. Réessaye dans un instant.");
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      await _authClient.signUp(email: email, password: password);
    } on AuthException catch (e) {
      throw AuthError.fromAuthException(e);
    } catch (e) {
      if (e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('socket') ||
          e.toString().toLowerCase().contains('connection')) {
        throw AuthError.networkError();
      }
      throw AuthError(
          "Oups, une petite erreur est survenue. Réessaye dans un instant.");
    }
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
  return ref
      .watch(authRepositoryProvider)
      .authStateChanges()
      .map((event) => event.session?.user);
}
