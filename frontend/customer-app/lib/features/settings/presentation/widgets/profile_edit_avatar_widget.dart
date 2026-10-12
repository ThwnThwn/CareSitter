import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ProfileEditAvatarWidget extends StatefulWidget {
  final String? avatarUrl;
  final XFile? localFile;
  final String initials;
  final bool isUploading;

  const ProfileEditAvatarWidget(
      {super.key,
      this.avatarUrl,
      this.localFile,
      required this.initials,
      required this.isUploading});

  @override
  State<ProfileEditAvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<ProfileEditAvatarWidget> {
  Uint8List? _localBytes;

  @override
  void didUpdateWidget(covariant ProfileEditAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.localFile != oldWidget.localFile) {
      _loadLocalBytes();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLocalBytes();
  }

  Future<void> _loadLocalBytes() async {
    if (widget.localFile == null) {
      if (_localBytes != null) setState(() => _localBytes = null);
      return;
    }
    final bytes = await widget.localFile!.readAsBytes();
    if (mounted) setState(() => _localBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (_localBytes != null) {
      image = MemoryImage(_localBytes!);
    } else if (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty) {
      image = NetworkImage(widget.avatarUrl!);
    }

    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        gradient: image == null ? AppColors.primaryGradient : null,
        shape: BoxShape.circle,
        boxShadow: AppShadows.elevated,
        image: image != null
            ? DecorationImage(image: image, fit: BoxFit.cover)
            : null,
        color: image != null ? AppColors.surfaceVariant : null,
      ),
      child: widget.isUploading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
          : image == null
              ? Center(
                  child: Text(
                    widget.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppFontSizes.s28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : null,
    );
  }
}
