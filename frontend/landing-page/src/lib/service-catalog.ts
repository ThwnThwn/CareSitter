export const serviceGroups = [
  {
    name: "Đồng hành & sinh hoạt",
    code: "A",
    services: [
      {
        name: "Trò chuyện, đồng hành và kích thích nhận thức nhẹ",
        hourlyPrice: 80000,
      },
      { name: "Đồng hành đi khám hoặc đi ra ngoài", hourlyPrice: 90000 },
      { name: "Hỗ trợ bữa ăn dinh dưỡng", hourlyPrice: 85000 },
    ],
  },
  {
    name: "Chăm sóc cá nhân",
    code: "B",
    services: [
      { name: "Vệ sinh cá nhân, tắm rửa và thay đồ", hourlyPrice: 120000 },
      { name: "Phòng ngừa té ngã và chăm sóc da", hourlyPrice: 120000 },
      { name: "Vận động nhẹ, hỗ trợ di chuyển", hourlyPrice: 130000 },
    ],
  },
  {
    name: "Điều dưỡng & chăm sóc y tế",
    code: "C",
    services: [
      {
        name: "Theo dõi sinh hiệu, tiêm và thay băng theo chỉ định",
        hourlyPrice: 200000,
      },
      { name: "Quản lý và theo dõi bệnh mạn tính", hourlyPrice: 220000 },
      { name: "Chăm sóc giảm nhẹ và cuối đời", hourlyPrice: 280000 },
    ],
  },
  {
    name: "Chăm sóc chuyên biệt",
    code: "D",
    services: [
      { name: "Vật lý trị liệu tại nhà", hourlyPrice: 250000 },
      { name: "Kích thích nhận thức CST/Montessori", hourlyPrice: 200000 },
      { name: "Châm cứu, bấm huyệt", hourlyPrice: 300000 },
    ],
  },
] as const;

export const carePackages = [
  {
    name: "An Nhiên",
    scope: "Đồng hành & chăm sóc cá nhân",
    groups: "Nhóm A + B",
    description:
      "Thêm một người đồng hành trong những việc thường ngày, từ bữa ăn, vệ sinh đến di chuyển và trò chuyện.",
    price: 800000,
    note: "Giá gói 1 ngày",
    featured: false,
  },
  {
    name: "An Khang",
    scope: "Sinh hoạt & điều dưỡng",
    groups: "Nhóm A + B + C",
    description:
      "Kết hợp hỗ trợ sinh hoạt với chăm sóc điều dưỡng theo nhu cầu được đánh giá và phạm vi chuyên môn được xác nhận.",
    price: 1120000,
    note: "Giá gói 1 ngày",
    featured: true,
  },
  {
    name: "Thân Trí",
    scope: "Vận động & nhận thức",
    groups: "Dịch vụ chuyên biệt",
    description:
      "Lựa chọn hỗ trợ chuyên biệt về vật lý trị liệu, kích thích nhận thức hoặc châm cứu, theo nhu cầu và điều kiện tiếp nhận.",
    price: null,
    note: "Tư vấn theo nhu cầu",
    featured: false,
  },
] as const;

export const packagePrices = [
  { label: "Gói 1 ngày", sessions: 1, anNhien: 800000, anKhang: 1120000 },
  { label: "2 ngày/tuần", sessions: 8, anNhien: 6000000, anKhang: 8400000 },
  { label: "3 ngày/tuần", sessions: 12, anNhien: 8800000, anKhang: 12320000 },
  { label: "4 ngày/tuần", sessions: 16, anNhien: 11500000, anKhang: 16100000 },
  { label: "5 ngày/tuần", sessions: 20, anNhien: 14000000, anKhang: 19600000 },
  { label: "6 ngày/tuần", sessions: 24, anNhien: 15500000, anKhang: 22680000 },
  { label: "Gói tháng", sessions: 30, anNhien: 16000000, anKhang: 25480000 },
] as const;

export function formatVnd(amount: number) {
  return `${new Intl.NumberFormat("vi-VN").format(amount)}đ`;
}
