import 'package:flutter/material.dart';

class CaregiverProfileFavoriteButton extends StatefulWidget {
  final String caregiverName;
  const CaregiverProfileFavoriteButton(
      {super.key, required this.caregiverName});

  @override
  State<CaregiverProfileFavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<CaregiverProfileFavoriteButton> {
  bool _isFav = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isFav ? Icons.favorite : Icons.favorite_border,
        color: Colors.white,
      ),
      onPressed: () {
        setState(() => _isFav = !_isFav);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFav
                ? 'Đã thêm ${widget.caregiverName} vào yêu thích'
                : 'Đã bỏ yêu thích ${widget.caregiverName}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}
