# Khắc phục cấu trúc frontend CareSitter

Cập nhật: 13/10/2026, Asia/Saigon. Phạm vi source từ `972414c` đến `305da0a`, gồm hai app Flutter, Admin, landing và API tiếp nhận yêu cầu tư vấn. Code đã commit; kiểm chứng dưới đây là local, chưa phải nghiệm thu production. Không build APK theo yêu cầu. Tài liệu này chỉ lưu local.

Nguồn chuẩn: [rule.frontend](../frontend/RULE_FRONTEND.md), [quy ước chung](../QUY_UOC_CODE_VA_SECRET.md). Đối chiếu [báo cáo cấu trúc ban đầu](FRONTEND_STRUCTURE_AUDIT_2026-10-12.md).

## Phần đã sửa

| Nhóm | Thay đổi và phạm vi |
| --- | --- |
| Cách ly phiên Customer | NotificationPrefs, AddressStore và FamilyContacts giữ danh tính cùng generation của lần đăng nhập; hủy I/O và timer khi đổi phiên; bỏ kết quả ghi đến muộn. Cache địa chỉ/danh bạ cũ được dọn trước khi tải tài khoản mới. Preference có trạng thái tải/lưu/lỗi, retry giữ draft và hàng đợi ghi tuần tự. |
| Core và App | Hai app chuyển triển khai notification routing về `app/push`; Core giữ port và messenger key generic. Provider được nối tại composition root. Bỏ vòng Toast → DeepLink → Router → Screen. |
| DTO và hiển thị | Bỏ barrel vòng BookingModel/BookingListResponse; UI lấy payment DTO từ models. Tách luật thao tác Shift/CareTask sang domain; chuyển nhãn ngày/giờ/thời lượng, lịch timeline và định dạng thông báo Caregiver về presentation. AddressModel Customer không còn getter hiển thị. |
| Booking Customer | BookingDetailContent từ 26 field còn bốn; callback thanh toán/theo dõi/hủy/hoàn tất có tên. BookingList tự đọc provider, BookingCard sở hữu layout và format tiền. TabController được dispose. Gia hạn ca hiển thị đúng giới hạn hiện tại vì backend chưa có API; bỏ thông báo đã gửi thành công giả. |
| Đăng ký hai app | Form giữ TextEditingController và trạng thái hiện/ẩn mật khẩu; controller giữ agreement, busy, error và submit lock. Màn hình quyết định điều hướng sau kết quả hợp lệ. Bỏ chuỗi factory/validator/callback truyền qua RegistrationContent. Customer giữ nội dung khi API lỗi và hỗ trợ chữ lớn. |
| Hồ sơ người thụ hưởng | Thêm và sửa dùng chung BeneficiaryProfileForm cùng các phần thông tin cơ bản, lưu ý và liên hệ khẩn cấp. UI đọc slice provider tại nơi dùng. Giữ sửa ngày sinh, giới tính, địa chỉ, draft và cảnh báo thoát. Xóa 28 widget cũ đã xác minh không còn tham chiếu từ lib/test; bản trước nằm trong Git. |
| Đề nghị nhận ca Caregiver | HomeOfferCard tự sở hữu WidgetRef; bỏ truyền hàm format tiền/địa chỉ/đếm ngược từ màn hình. HomeOfferActions dùng onAccept/onDecline; nội dung có onOpen/onOpenQueue. Giữ khóa, hết hạn và sự tách biệt giữa bấm hành động với mở chi tiết. |
| Theme và tham số dư | Customer tách colors/spacing/radius/layout/breakpoints/shadows khỏi AppTheme. Thêm token cho giá trị đang dùng trong form/card. Bỏ setState dư trong TagInput cũ, args của SavedSelfRecipient và badgeColor của KpiItem. Chưa chuẩn hóa mọi literal trong toàn app. |
| Guard kiến trúc | Hai app dùng cùng graph helper đọc import/export/conditional import qua AST, resolve cả package và relative URI, kiểm tra cycle, Core → App/features, data → presentation, UI → repository và presentation riêng của feature khác. Giữ kiểm tra kích thước UI/build. |
| Admin | ServicesPage/PromotionsPage tách thành module catalog/promotions với API adapter, hook quản lý draft/mutation và component form. JSX được format để review được. Các sửa Admin có sẵn từ trước vẫn giữ riêng. |
| Landing | Page là server component với provider client cho tương tác. CSS 2.481 dòng được chia theo phần. Có job riêng chạy lint/typecheck/test/build trong CI. |

## Yêu cầu tư vấn

- Landing lấy họ tên, điện thoại, loại hỗ trợ, ngày, thời lượng, ghi chú và đồng ý liên hệ. Gửi qua `/api/consultation-requests` tới `POST /api/v1/consultation-requests`. Chỉ hiện đã lưu sau khi nhận biên nhận hợp lệ.
- Support module ghi vào `support.consultation_requests`. UUID là khóa idempotency bền; đối chiếu hash payload đã chuẩn hóa. Request đồng thời cùng key/payload trả cùng biên nhận; payload khác nhận conflict. Retry qua nửa đêm vẫn trả bản đã lưu.
- Response công khai chỉ chứa ID/thời điểm. `GET /api/v1/consultation-requests` kiểm tra quyền ADMIN tại HTTP và use case, có phân trang; Admin xem tại **Hỗ trợ → Yêu cầu tư vấn**.
- Client giữ fingerprint/key trong sessionStorage để gửi lại khi mất response; không lưu thông tin liên hệ ở đó. Proxy kiểm tra origin, body, timeout và lỗi backend. Native dialog được kiểm tra tại chiều rộng 320px: không tràn ngang, kiểm tra trường bắt buộc, báo lỗi, đóng Escape và khôi phục focus.

Để chạy trên môi trường có DB cũ, cần áp dụng [SQL 39](../../backend/init-db/39-consultation-requests.sql) theo quy trình migration hiện có và đặt `CARESITTER_API_BASE_URL` ở server landing theo [mẫu cấu hình](../../frontend/landing-page/.env.example). Lượt này chưa áp migration lên DB dev/production hoặc deploy API. Restart container không tự áp SQL mới lên volume cũ.

Rate limiter backend hiện dùng IP peer kết nối, 20 lượt/phút. Qua Next proxy, nhiều khách có thể chia sẻ cùng peer; cần cấu hình proxy/rate limit theo topology thực khi triển khai. Chưa thêm luồng phân công/trạng thái xử lý tư vấn hoặc gửi email/SMS tự động.

## Kiểm chứng

| Kiểm tra | Kết quả |
| --- | --- |
| Customer `flutter analyze --no-pub` | Không có issue |
| Customer full `flutter test --no-pub --reporter expanded` | 254 pass, 0 fail, 0 skip |
| Caregiver `flutter analyze --no-pub` | Không có issue |
| Caregiver full `flutter test --no-pub --reporter expanded` | 88 pass, 0 fail, 0 skip |
| Admin working tree test/build | 66 pass; build đạt |
| Admin snapshot từ commit test/build | 60 pass; build đạt. Sáu test local có sẵn của người dùng không nằm trong commit đợt này. |
| Landing contract/client/proxy test | 10 pass, 0 skip; typecheck/lint đạt |
| Landing build từ working tree và source trong commit | Đạt; snapshot cài dependency từ lockfile |
| Consultation + đăng ký handler MediatR, PostgreSQL thật | 15 pass, 0 skip; gồm tám request đồng thời và retry qua nửa đêm. Snapshot commit cũng đạt 15/15. |
| Staged source | Diff check đạt; không có Markdown, env thật hoặc sửa Nutrition có sẵn |

Log và TRX nằm trong `backend/artifacts/frontend-logic-20261012/`, gồm `customer-final-full-tests.log`, `caregiver-final-full-tests.log`, các log `*-final-analyze.log`, `committed-postgres/` và `committed-landing-build.log`. Runner tạo/xóa container PostgreSQL test riêng, không sửa DB đang dùng. Các sửa cuối chỉ bỏ tham số dư/const/import, đã được analyze; full suite phía trên chạy trước các sửa không đổi hành vi đó.

Chưa chạy thiết bị thật, APK/iOS, nghiệm thu thanh toán hay toàn bộ Phase 7 baseline trong lượt này. Browser kiểm tra bố cục và validation; kiểm chứng client/proxy và lưu SQL chạy riêng, chưa phải một flow POST từ browser đến API/DB đã triển khai. Chưa xác nhận trạng thái CI mới trên GitHub.

## Phần còn lại theo thứ tự

1. Customer Activity/Tracking và một số dialog/action widget Booking vẫn chia theo cây build, cần gom thành section/card có nghĩa. Quét tên hiện còn 100 file Customer và 63 file Caregiver chứa `callbackActionN`; đây là tín hiệu rà, không phải kết luận mọi file đó đều lỗi.
2. Caregiver Shift detail, Home ngoài offer và các form profile/KYC tiếp tục cần rà cách truyền factory, Ref và callback. Không đánh dấu toàn FE clean chỉ từ các nhóm đã sửa.
3. Chuẩn hóa spacing/radius/formatter còn rải ở widget; thống nhất status view model của Activity. Shift mapper vẫn có fallback tên/initials hiển thị cần tách tiếp nếu thay hợp đồng DTO.
4. Landing AI còn contract đầu ra khai báo riêng ở route và client; cần validator/test dùng chung. CustomCursor chưa dùng và các file candidate không có importer cần rà từng file trước khi xóa.
5. Workspace còn thay đổi local Nutrition/gRPC/AppHost, Admin bootstrap, tài liệu và preview từ trước. Giữ nguyên; chúng chưa được đưa vào commit đợt này.

## Commit

- `2b2dbd5`: cách ly phiên và guard ranh giới hai app.
- `338b9d4`: lưu yêu cầu tư vấn, Admin inbox, client/server boundary và CI landing.
- `c524dbe`: tách editor catalog/promotions.
- `8d4d318`: bỏ xác nhận gia hạn chưa được backend hỗ trợ.
- `35acac1`: cách ly danh bạ gia đình theo phiên.
- `06a9816`: form đăng ký/hồ sơ và danh sách booking Customer.
- `305da0a`: controller đăng ký và thẻ đề nghị nhận ca Caregiver.
