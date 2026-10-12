/// Dữ liệu tiền đầu vào vẫn do backend quyết định; FE chỉ suy ra từ DTO.
class BookingAmountRules {
  static int payable(int escrow, int? customerPayable) =>
      customerPayable ?? escrow;
  static int caregiverEarning(int escrow, int platformFee) =>
      escrow - platformFee;
}
