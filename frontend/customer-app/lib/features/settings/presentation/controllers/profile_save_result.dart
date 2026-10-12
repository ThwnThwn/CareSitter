class ProfileSaveResult {
  const ProfileSaveResult(
      {this.saved = false,
      this.avatarUploaded = false,
      this.ignored = false,
      this.message});
  final bool saved, avatarUploaded, ignored;
  final String? message;
}
