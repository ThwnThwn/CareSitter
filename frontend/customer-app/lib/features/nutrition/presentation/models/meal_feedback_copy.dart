class MealFeedbackCopy {
  static const labels = {
    'liked': 'Thích món này',
    'disliked': 'Không hợp khẩu vị',
    'want_again': 'Muốn ăn lại'
  };
  static String effect(String name, String feedback) => feedback == 'disliked'
      ? 'Duyệt sẽ thêm “$name” vào món không thích và gỡ cùng món khỏi danh sách thích.'
      : 'Duyệt sẽ thêm “$name” vào món thích và gỡ cùng món khỏi danh sách không thích.';
}
