# CareSitter - Interactive Motion Landing Page (Solid Green & White)

Trang Landing Page chính thức cho nền tảng **CareSitter** (Smart Family Care), được xây dựng theo phong cách thiết kế **Solid Green & White** tối giản, thanh lịch và giàu tính tương tác từ Stitch Design System.

## Công nghệ sử dụng

- **Framework**: Next.js 16 (App Router) + React 19 + TypeScript
- **Styling**: Tailwind CSS v4 + Vanilla CSS Design Tokens
- **Icons**: Lucide React + Material Symbols
- **Motion & Interactions**:
  - Custom Cursor (Ring follower + Center dot tracking)
  - Top Reading Scroll Progress Bar
  - Word Reveal Hero Entrance Animation
  - 3D Phone Mockup (iOS bezel, Dynamic Island, live app UI preview)
  - Animated Number Counters with IntersectionObserver
  - 3-Step Interactive Process with animated SVG dashed connecting line
  - Continuous Seamless Caregivers Carousel (Tự động cuộn mượt mà, pause khi hover)
  - Asymmetric Bento Grid (GPS live radar & pin drop, Shield verification, In-app chat, Interactive monthly calendar)
  - Interactive Quick Booking Modal (Dự toán chi phí tức thì theo giờ & ngày)
  - 3D Tilt Testimonial cards
  - High-converting CTA with 360-spin animated QR Code

## Khởi chạy dự án

### 1. Cài đặt dependencies
```bash
npm install
```

### 2. Chạy môi trường Development
```bash
npm run dev
```
Truy cập trình duyệt tại: [http://localhost:3000](http://localhost:3000)

### Trợ lý AI chọn dịch vụ

Landing page có trợ lý AI trong hero để đọc mô tả nhu cầu của gia đình và gợi ý loại hỗ trợ cùng số giờ ban đầu. API key chỉ được đọc ở Route Handler phía server, không đưa vào trình duyệt.

Tạo file `.env.local` trong thư mục `frontend/landing-page`:

```env
OPENAI_API_KEY=your_api_key_here
OPENAI_MODEL=gpt-5-mini
```

Nếu chưa cấu hình key, nút trợ lý vẫn mở bình thường và hướng người dùng sang form đặt ca. Trợ lý chỉ đưa gợi ý phi y tế; người dùng vẫn xác nhận thông tin trong bước đặt ca.

### 3. Build & Run Production
```bash
npm run build
npm start
```

## Cấu trúc thư mục

```
landing-page/
├── public/
│   ├── favicon.ico
│   └── images/              # Assets hình ảnh (Caregivers, App preview)
├── src/
│   ├── app/
│   │   ├── globals.css      # Design tokens, custom keyframes & utility classes
│   │   ├── layout.tsx       # Fonts (Be Vietnam Pro, Plus Jakarta Sans, Inter), Metadata & SEO
│   │   └── page.tsx         # Trang chủ tích hợp tất cả các components
│   └── components/
│       ├── CustomCursor.tsx        # Con trỏ chuột tương tác (desktop)
│       ├── Header.tsx              # Sticky Header & Mobile menu drawer
│       ├── HeroSection.tsx         # Hero section & 3D Interactive Phone Mockup
│       ├── StatsSection.tsx        # Bộ đếm chỉ số động (50.000+, 4.9★, <10m, 98%)
│       ├── HowItWorksSection.tsx   # 3 Bước đặt ca & đường nối SVG
│       ├── CaregiversSection.tsx   # Carousel vô tận các chuyên viên chăm sóc
│       ├── FeaturesSection.tsx     # Bento grid các tính năng nổi bật
│       ├── TestimonialsSection.tsx # Đánh giá 5 sao từ các gia đình
│       ├── DownloadCTASection.tsx  # Banner tải app & quét mã QR
│       ├── QuickBookModal.tsx      # Modal đặt ca tương tác & tính giá tức thời
│       └── Footer.tsx              # Chân trang đầy đủ thông tin & liên kết
├── next.config.ts
├── package.json
└── tsconfig.json
```
