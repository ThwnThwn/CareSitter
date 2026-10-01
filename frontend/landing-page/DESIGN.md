# CareSitter Landing Page Design System

## Direction

MedScan (`https://medscan.framer.website/`) là tham chiếu thị giác chính cho landing page. CareSitter sử dụng cùng tinh thần về màu sắc và typography: nền off-white, teal đậm, mint sáng, display serif giàu tính biên tập và sans-serif rõ ràng cho nội dung. Hệ thống này được điều chỉnh cho tiếng Việt, ngữ cảnh chăm sóc tại nhà phi y tế và khả năng đọc của người dùng trung niên.

Không sao chép logo, nội dung, hình ảnh, component hoặc bố cục nguyên bản của MedScan.

## Color Strategy

Chiến lược màu: **Committed**. Off-white là canvas; teal là màu thương hiệu và CTA; đen xanh dùng cho các section có độ tương phản cao; mint dùng cho surface và trạng thái tin cậy. Cam chỉ xuất hiện ở tín hiệu phụ cần nổi bật.

| Token | Giá trị | Vai trò |
| --- | --- | --- |
| `--paper` | `#F5F3EE` | Nền trang chủ đạo, lấy trực tiếp từ MedScan |
| `--paper-deep` | `#E6F4F1` | Surface mint, khối thông tin nhẹ |
| `--green` | `#006B5B` | Primary teal, CTA, link và điểm nhấn |
| `--green-bright` | `#00C896` | Accent sáng, progress và trạng thái tích cực |
| `--green-dark` | `#0D1117` | Section tối, footer và modal overlay base |
| `--ink` | `#0D1117` | Heading và body text chính |
| `--medscan-slate` | `#718096` | Màu slate nguyên bản của MedScan, chỉ dùng cho metadata lớn khi đủ tương phản |
| `--muted` | `#536471` | Slate đã làm tối để body text đạt WCAG AA trên `--paper` |
| `--line` | `#E2DDD5` | Divider và border trung tính |
| `--amber` | `#FF6B35` | Accent hiếm: rating hoặc cảnh báo nhẹ |
| `--white` | `#FFFFFF` | Text trên nền tối và surface cao nhất |

### Color rules

- CTA chính luôn dùng `--green` với chữ trắng.
- Section tối dùng `--green-dark`; chữ phụ dùng trắng có alpha, không dùng slate xám.
- Mint `--paper-deep` biểu thị tin cậy, xác minh hoặc surface hỗ trợ; không dùng như màu trang trí ngẫu nhiên.
- `--green-bright` chỉ chiếm một phần nhỏ để giữ sức hút thị giác.
- Body text phải đạt tối thiểu 4.5:1; UI/icon phải đạt tối thiểu 3:1.

## Typography

### Font families

| Role | Font | Weight/style | Usage |
| --- | --- | --- | --- |
| Display | **Instrument Serif** | 400 normal, 400 italic | H1–H3, số liệu lớn, quote, logo wordmark |
| Body/UI | **DM Sans** | 400, 500, 600, 700 | Body copy, navigation, button, form và UI text |
| Labels | **IBM Plex Mono** | 500, 600 | Section label, metadata, trạng thái và nhãn ngắn |

Các font được self-host qua `next/font/google` với `display: swap`. Instrument Serif và DM Sans tải bộ `latin-ext`; IBM Plex Mono tải thêm bộ `vietnamese`.

### Type rules

- Display heading dùng `Instrument Serif`, letter-spacing `0`, line-height khoảng `1.02–1.14`.
- Phần nhấn trong heading dùng Instrument Serif italic và màu `--green`.
- Body dùng DM Sans ở cỡ tối thiểu `1rem`; line-height `1.6–1.75`; độ dài dòng tối đa 65–75 ký tự.
- IBM Plex Mono chỉ dùng cho nhãn ngắn. Không dùng mono cho đoạn văn hoặc heading dài.
- Type scale cho marketing dùng `clamp()` và không vượt quá `6rem`.

## Shape and Layout

- Border radius mặc định: `14px`; pill chỉ dành cho tag hoặc button.
- Layout ưu tiên typography, ảnh thật và divider; tránh lặp card grid đồng đều.
- Section dùng nhịp spacing lớn, thay đổi theo nội dung; container tối đa `1240px`.
- Ảnh sử dụng crop rõ chủ thể và alt text mô tả tình huống chăm sóc.

## Motion and Accessibility

- Hero giữ entrance motion nhẹ; khu vực review dùng carousel có card trung tâm, hai card kế cận hé lộ, kéo/vuốt ngang, nút điều hướng và dot navigation. Pattern tham chiếu từ `https://dizzy-help-953422.framer.app/`, nhưng được chuyển sang palette và typography của CareSitter thay vì sao chép nguyên mẫu.
- Carousel chính chuyển slide bằng `transform`, `opacity` và `scale` trong 550ms với ease-out-quint (`0.22, 1, 0.36, 1`), không autoplay để người dùng có đủ thời gian đọc. Một hàng review compact bên dưới chạy marquee tuyến tính 42 giây để tạo nhịp liên tục; hàng này dừng khi hover/focus, có nút pause/play và trở thành danh sách cuộn ngang tĩnh khi bật Reduce Motion.
- Mask mờ ở hai mép chỉ dùng để gợi ý còn nội dung; card active luôn đủ tương phản và là item duy nhất được screen reader đọc.
- Mọi animation phải có phương án `prefers-reduced-motion`.
- Focus ring dùng mint sáng trên nền tối hoặc teal trên nền sáng.
- Trang phải hoạt động ở 320px+, zoom 200%, điều hướng bàn phím và không tràn ngang.
