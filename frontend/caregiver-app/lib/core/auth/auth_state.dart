import 'package:equatable/equatable.dart';

class AuthState extends Equatable {
  final String? accessToken;
  final String? refreshToken;
  final String? userId;
  final String? phone;
  final List<String> roles;
  final bool isAuthenticated;

  const AuthState({
    this.accessToken,
    this.refreshToken,
    this.userId,
    this.phone,
    this.roles = const [],
    this.isAuthenticated = false,
  });

  const AuthState.initial() : this(isAuthenticated: false);

  AuthState copyWith({
    String? accessToken,
    String? refreshToken,
    String? userId,
    String? phone,
    List<String>? roles,
    bool? isAuthenticated,
  }) {
    return AuthState(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      userId: userId ?? this.userId,
      phone: phone ?? this.phone,
      roles: roles ?? this.roles,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }

  @override
  List<Object?> get props =>
      [accessToken, userId, phone, roles, isAuthenticated];
}
