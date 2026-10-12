class BeneficiaryFormOptions {
  const BeneficiaryFormOptions._();
  static const relations = [
    'Bố',
    'Mẹ',
    'Ông',
    'Bà',
    'Vợ/Chồng',
    'Anh/Chị/Em',
    'Con',
    'Khác'
  ];
  static const genders = {
    'MALE': 'Nam',
    'FEMALE': 'Nữ',
    'OTHER': 'Khác',
    'UNSPECIFIED': 'Chưa xác định',
  };
  static const careLevels = ['Nhẹ', 'Trung bình', 'Nặng'];
  static const contactRelations = [
    'Con trai',
    'Con gái',
    'Vợ',
    'Chồng',
    'Anh/Chị/Em',
    'Bố/Mẹ',
    'Bạn bè',
    'Người thân',
    'Khác'
  ];
}
