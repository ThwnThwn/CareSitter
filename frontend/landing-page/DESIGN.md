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
| `--green-bright` | `#00C896` | Accent sáng và trạng thái tích cực |
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

- Chuyển động được đối chiếu trực tiếp với MedScan: Lenis làm mượt cuộn với lerp 0.1; anchor tính scroll-padding của header, menu và modal khóa cuộn nền. Cảm ứng vẫn dùng cuộn tự nhiên.
- Hero copy giữ entrance đi lên 150px, riêng H1 170px; kicker, H1, đoạn dẫn, CTA và proof lần lượt trễ 200/400/600/800/1000ms, duration 1200ms và ease-out-expo.
- Riêng cụm ảnh hero dùng Anime.js: ảnh chính về vị trí từ góc nghiêng 1,2° và khoảng dịch 36px; ảnh chân dung, dấu xác minh và thẻ cập nhật vào lệch nhịp 120–570ms với ease-out-expo. Ảnh chính thu nhẹ từ 1,045 về 1 trong khung crop; ba lớp phụ trôi 4–6px. Desktop có chiều sâu theo chuột tối đa 8,4px; mobile giảm biên độ. Chỉ chạy khi ảnh tải và cụm ảnh vào viewport, tạm dừng ngoài màn hình hoặc khi tab ẩn, dọn animation và listener khi unmount. Nút phát/tạm dừng trong cụm ảnh cho phép điều khiển; mặc định tắt khi hệ điều hành yêu cầu giảm chuyển động, có thể chủ động bật lại bằng nút phát. Nội dung vẫn hiển thị khi không có JavaScript.
- H2 hiện từng từ: blur 10px → 0, opacity 0.001 → 1, đi lên 10px trong 500ms, lệch mỗi từ 50ms. Giữ nguyên ngữ nghĩa, nhấn italic và xuống dòng tiếng Việt. Đoạn dẫn giữ tĩnh như trang tham chiếu.
- Feature và số liệu đi lên 36px/fade trong 650ms; quy trình, toàn bộ thẻ caregiver, review và CTA đi lên 150px/fade trong 1100ms. Chạy một lần khi vào viewport và tự hoàn tất khi ngừng cuộn, không scrub theo vị trí cuộn. Dùng thuộc tính translate riêng để không ghi đè transform căn giữa của carousel.
- Nội dung mặc định luôn hiển thị, kể cả không có JavaScript; chỉ áp dụng animation trong lúc chạy và dọn hiệu ứng sau khi kết thúc. Các hiệu ứng landing mặc định bật theo yêu cầu, không cần query `?motion=on` hoặc nút điều khiển.
- Khu vực review dùng carousel có card trung tâm, hai card kế cận hé lộ, kéo/vuốt ngang, phím mũi tên và dot navigation căn giữa. Không hiển thị hướng dẫn kéo/vuốt hoặc cụm mũi tên/số trang hai bên. Pattern tham chiếu từ `https://dizzy-help-953422.framer.app/`, nhưng được chuyển sang palette và typography của CareSitter thay vì sao chép nguyên mẫu.
- Navigation theo MedScan: nền paper đặc, cuộn xuống ẩn bằng translateY(-150px)/opacity, cuộn lên hiện lại với ease-out-expo 500ms. Luôn hiện ở đầu trang, khi mở menu hoặc khi focus bàn phím; bỏ qua dao động cuộn dưới 6px. Link hover đổi teal và hiện gạch chân; nút CTA hover dùng teal #00806D, không dùng màu section tối.
- Carousel chính chuyển slide bằng `transform`, `opacity` và `scale` trong 550ms với ease-out-quint (`0.22, 1, 0.36, 1`), không autoplay để người dùng có đủ thời gian đọc. Hàng review compact bên dưới chạy marquee tuyến tính 42 giây liên tục, kể cả khi hệ điều hành bật Reduce Motion, theo lựa chọn cụ thể của trang; không có nút bật/tắt.
- Mask mờ ở hai mép chỉ dùng để gợi ý còn nội dung; card active luôn đủ tương phản và là item duy nhất được screen reader đọc.
- Entrance, cuộn mượt, carousel và marquee là ngoại lệ `prefers-reduced-motion` theo yêu cầu luôn chuyển động của trang. Các transition trang trí khác vẫn tôn trọng cài đặt hệ điều hành.
- Focus ring dùng mint sáng trên nền tối hoặc teal trên nền sáng.
- Trang phải hoạt động ở 320px+, zoom 200%, điều hướng bàn phím và không tràn ngang.
