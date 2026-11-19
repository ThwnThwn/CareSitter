import 'package:flutter/material.dart';

class LoginGoogleButton extends StatelessWidget {
  const LoginGoogleButton({
    super.key,
    required this.onPressed,
    required this.loading,
  });

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: onPressed,
          icon: loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Image.asset(
                  'assets/icons/google-g.png',
                  width: 20,
                  height: 20,
                  excludeFromSemantics: true,
                ),
          label: Text(loading ? 'Đang đăng nhập…' : 'Tiếp tục với Google'),
        ),
      );
}
