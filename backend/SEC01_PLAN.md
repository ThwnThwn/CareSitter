# SEC01 — CCCD/KYC media hardening

Ngày: 04/10/2026 (Asia/Saigon). Phạm vi đợt này: code local trên develop; không push/deploy, không đọc hoặc thay đổi ảnh/DB Cloudinary thật.

## Đánh giá trước triển khai

Điểm mạnh: CCCD đã có encryption/HMAC; caregiver/admin có role boundary và session revocation; Catalog đã sở hữu media_assets với owner; module boundary và PostgreSQL baseline có kiểm thử.

Rủi ro P0: upload KYC dùng delivery mặc định public; submit nhận URL HTTP tùy ý; API trả URL cũ cho caregiver/admin; signed URL stub; chỉ dùng private có thể vẫn public derivatives; URL ký thông thường không tự hết hạn. Kiểm tra lại theo [Cloudinary access control](https://cloudinary.com/documentation/control_access_to_media) và [Upload API](https://cloudinary.com/documentation/image_upload_api_reference).

Rủi ro rollout: app cũ không tương thích hợp đồng media ID; ảnh public/CDN cũ không tự thu hồi khi sửa code; authenticated proxy thêm bandwidth/load; nhiều API replica cần cùng Data Protection key ring; orphan upload cần retention/cleanup được duyệt. Không đoán public_id hoặc fetch URL do client gửi.

## Phương án và thứ tự

1. Upload KYC server-side Type=authenticated (original và derivatives), public ID ngẫu nhiên, overwrite=false; lưu owner, document type, format và delivery type. Không trả Cloudinary URL. Folder/documentType bind rõ FromForm; multipart KYC không được rơi vào upload public do binder đọc sai nguồn.
2. Submit nhận media IDs; bắt buộc đúng owner, đúng CCCD_FRONT/CCCD_BACK/certificate, không trùng và tối đa 10 certificate. Lưu reference trong People, không lưu bearer URL.
3. API cấp ticket ngắn hạn tối đa 5 phút (endpoint cấp 120 giây) gắn media ID + user; ticket đi qua header X-Kyc-Read-Ticket, không qua query/URL logs. Content endpoint vẫn bắt JWT và kiểm tra quyền mỗi lần. Caregiver chỉ xem ảnh mình; admin chỉ xem ảnh đã submit, không xem orphan. Backend fetch private_download_url có expires_at; không redirect; giới hạn 10 MB/30 giây và media API 120 request/phút/actor; response no-store, no-referrer, nosniff. Không lộ provider URL/secret qua log hoặc payload. CreateSignedUrlAsync dùng URI fragment (không gửi lên HTTP); client nên dùng structured grant từ POST /media/{id}/access.
4. DTO không trả legacy KYC URLs; cờ cần chuyển đổi an toàn. Không cho approve hồ sơ URL-only; caregiver DRAFT/REJECTED nộp lại bằng ảnh mới. Giữ dữ liệu legacy cho kế hoạch migration/revoke có kiểm soát, không xóa tự động hoặc tự thay trạng thái APPROVED.
5. Caregiver upload từng document type và submit media ID; admin fetch ảnh bằng Authorization, dùng blob URL trong bộ nhớ và thu hồi khi đóng drawer; loading/error/retry rõ ràng. Giữ nguyên thiết kế UI.
6. Test owner/role/anonymous/tamper/TTL/revoke, provider fail-closed, old URLs, submit mismatch, approve legacy, migration mới + replay; chạy baseline và frontend tests/build.

## Điều kiện chưa được coi gate production đạt

- Sandbox Cloudinary: anonymous original/derivative và URL cũ phải bị chặn; thử TTL thật, lỗi provider, session revoke.
- Inventory legacy, chuyển tài liệu sang authenticated theo asset đã xác minh; CDN invalidate/revoke và truy cập lại URL cũ. Cần duyệt riêng trước remote mutations.
- Chính sách admin KYC least privilege/MFA (SEC02), audit retention, media deletion/orphan cleanup, chia sẻ key ring giữa replica và load test proxy.
- Evidence booking/selfie/checklist/support/medical media ngoài KYC vẫn cần đợt riêng. Không ghi SEC01 toàn dự án hoàn thành chỉ vì CCCD/KYC local tests đạt.

## Kết quả triển khai

Đã triển khai và kiểm thử local trên develop. **Luồng KYC mới đạt kiểm thử local; SEC01 production chưa đóng.**

- Cloudinary authenticated upload, media metadata do Catalog sở hữu; quyền liên kết hồ sơ do People cung cấp qua Contracts. API submit/approve kiểm tra owner/purpose/delivery, không tin URL client.
- CreateSignedUrlAsync không còn trả chuỗi rỗng. Trả URI của API kèm ticket trong fragment; đó không phải URL ảnh Cloudinary để dán thẳng vào img. Structured grant là hợp đồng ưu tiên cho client.
- Backend proxy kiểm tra ticket và quyền hiện tại mỗi GET, không redirect/provider URL. HttpClient download tắt URL loggers; audit chỉ action/media ID/type. Admin dùng blob trong bộ nhớ, abort/revoke khi đóng/chuyển hồ sơ, có lỗi/thử lại; caregiver gửi media IDs. Áp dụng skill fk cho thay đổi hợp đồng/trạng thái UI, giữ bố cục cũ, không redesign.
- API không trả URL legacy và chặn approve URL-only. Dữ liệu URL legacy vẫn giữ trong DB để migration có kiểm soát; chưa thu hồi ảnh public/CDN thật, chưa đổi trạng thái hồ sơ APPROVED.
- Bổ sung migration 32 additive/replay-safe. PostgreSQL KYC tests phát hiện lỗi spatial mapping phụ thuộc thứ tự mở connection; People/Catalog chuyển sang NpgsqlDataSource có NTS mapping rõ ràng ở cả ADO.NET/EF, theo [tài liệu Npgsql](https://www.npgsql.org/efcore/mapping/nts.html). Không sửa schema/domain booking để né lỗi.
- Sửa khai báo multipart: IFormFile được suy luận tự động; folder/documentType bind FromForm. Sửa Swagger filter nhận scalar form fields của Minimal API; kiểm thử Swagger và upload multipart thật cùng một host. Rate limiter chuyển sau authentication, trước authorization để chia hạn mức media theo JWT actor; auth policies vẫn theo IP.

### Evidence local — 04/10/2026

- Backend Release build: 0 warning/error. Hai vòng baseline liên tiếp, mỗi vòng **338/338**, 0 fail/skip, 6 TRX/vòng. Schema 00–32, legacy 00–25 → 26–32/replay và smoke đạt. Evidence: `backend/artifacts/sec01-20261004-final-acceptance/summary.json` và `tests-run-1`, `tests-run-2`.
- Trong baseline có 39 case media security/TestHost (quyền, TTL, tamper, provider fail-closed, multipart/Swagger/no-store), 3 case KYC PostgreSQL, regression legacy resubmission và thứ tự middleware.
- Admin: **38/38**, TypeScript/Vite build đạt; JUnit `frontend/admin-web/test-results/sec01.xml`. Caregiver: analyze sạch, **17 test**, web release build đạt. Customer không đổi source: analyze sạch, **55 test**. Chưa chạy browser/device QA cho luồng này.
- Native runner regression đạt: exit/quoting/log drain, stop khi đang ghi log qua 5 process, lỗi log pump và lỗi startup.
- Một lượt nested pwsh bị treo sau khi test xanh nhưng trước summary; đã dừng đúng process test, dọn 5 container test của lượt đó, giữ log/TRX ở `backend/artifacts/sec01-20261004-release-candidate`. Không dùng lượt đó làm evidence baseline hoàn tất. Lượt nghiệm thu cuối chạy trực tiếp bằng `./backend/scripts/test-phase7.ps1`; nguyên nhân treo nested chưa được kết luận.
- Bốn thư mục config/SQL test trong Temp của RunId `20261004-125150-d4481ef4` còn giữ lại: policy máy chặn lệnh cleanup thủ công. Không cố vượt policy; đây là tài nguyên test, không phải DB/ảnh người dùng. Docker volumes của lượt dừng cũng giữ lại, không prune volume chung. Lượt nghiệm thu cuối đã tự cleanup container/thư mục của chính nó.
- Summary fingerprint ghi nhận source ổn định trong lúc chạy; sau nghiệm thu chỉ cập nhật SEC01_PLAN/PRODUCTION_PROGRESS, không sửa runtime/test/schema. Các provider tests dùng giả lập, không chứng minh Cloudinary account thật đã khóa original/derivative.
- Không commit/push/merge/deploy, không gọi Cloudinary thật hoặc chạy migration lên DB dev/production. Ảnh và .kombai customer-app ngoài phạm vi được giữ nguyên.

## Hợp đồng tích hợp mới

1. Caregiver có JWT gửi multipart tới `POST /api/v1/media/upload`: file + folder=kyc + documentType. Type hợp lệ: CCCD_FRONT, CCCD_BACK, NURSING_CERT, HEALTH_CERT, CRIMINAL_RECORD, OTHER. Kết quả chỉ có mediaId. JPG/PNG/WEBP, tối đa 10 MB, kiểm tra chữ ký file và hợp đồng provider; không fallback sang public upload.
2. `POST /api/v1/caregivers/me/kyc` nhận cccdNumber, cccdFrontMediaId, cccdBackMediaId, certificateMediaIds (tối đa 10). Hai mặt CCCD bắt buộc, cùng owner, đúng purpose; không nhận URL. CCCD vẫn mã hóa/HMAC như trước.
3. Actor được phép gọi `POST /api/v1/media/{id}/access`, nhận url tương đối + ticket + expiresInSeconds=120. GET url với cả Authorization Bearer và X-Kyc-Read-Ticket. URL/ticket không đủ để xem nếu thiếu JWT/quyền; ticket không được đưa vào query, log, localStorage hoặc analytics. Caregiver xem của mình; ADMIN chỉ xem asset đã liên kết hồ sơ.

## Runbook trước pilot/production — chưa thực hiện

1. Chốt người phụ trách security/Cloudinary và cửa sổ rollout. Cấp sandbox bằng secret manager/env riêng, không gửi API secret trong chat hoặc commit. Dùng giấy tờ giả lập, không upload CCCD thật để thử nghiệm.
2. Backup DB và nghiệm thu restore trước migration. Xác minh schema 00–31, review `init-db/32-secure-kyc-media.sql`, áp dụng 32 ở sandbox rồi xác minh 5 cột mới + replay. Với Docker đã nâng tới 31, chỉ sau khi xác minh đúng target mới chạy `./backend/scripts/update-db.ps1 -From 32 -SkipStart -ContainerName <đúng-container>`; không dùng default container nếu chưa kiểm tra. DB khác dùng quy trình migration được duyệt, không tự áp dụng lệnh Docker production.
3. Triển khai API/caregiver/admin theo cùng hợp đồng media ID; chặn hoặc yêu cầu cập nhật app cũ. Tạm dừng nộp/duyệt KYC trong cửa sổ không tương thích; không giữ endpoint public URL để hỗ trợ app cũ.
4. Cấu hình Data Protection key ring bền vững, bảo vệ at-rest, cùng application discriminator/key ring trong các replica của một môi trường; tách sandbox/production. Kiểm thử cấp grant ở replica A, đọc ở B, restart và key rotation. Kiểm tra proxy/WAF/CORS không log bearer/ticket/signed provider URL và không cache private content.
5. Cloudinary sandbox: xác minh metadata type=authenticated; anonymous original và derivative URL không truy cập được; private_download_url hết hạn đúng expires_at. API: anonymous/khác owner/customer/orphan admin/ticket sửa/hết hạn bị chặn; session revoke và unlink chặn lần GET kế tiếp; provider timeout/redirect/HTML/lỗi không lộ URL và UI cho thử lại. Kiểm tra log/analytics không chứa tài liệu, CCCD, token hoặc provider URL.
6. Inventory legacy bằng asset identity đã xác minh, không đoán public_id từ URL client. Lập danh sách owner/profile/object/delivery và phương án chuyển sang authenticated; giữ trạng thái APPROVED theo quy trình được duyệt. Với hồ sơ PENDING cũ, hướng dẫn từ chối để caregiver nộp lại bằng ảnh mới. Mọi copy/change delivery/revoke/CDN invalidate cần phê duyệt riêng; kiểm tra lại URL cũ và derivatives sau thu hồi. Ẩn URL trong DTO không đáp ứng bước này.
7. Nghiệm thu retention/xóa tài liệu/orphan cleanup, least-privilege/MFA admin, audit và điều tra sự cố. Upload thành công nhưng DB/audit lỗi có thể để orphan; không tự xóa remote trong đợt này. Rate 120/phút/actor hiện là in-process/per replica, chưa thay thế global concurrency/bandwidth controls; load test giới hạn RAM/30 giây/provider quota trước scale.
8. Rollback phải giữ cột/media references additive và ảnh authenticated; không downgrade delivery sang public. Nếu quay về app cũ, khóa upload/submit/duyệt KYC thay vì mở lại public flow. Không drop cột 32 hoặc xóa asset như một bước rollback tự động.
9. Chỉ đóng SEC01 CCCD/KYC sau khi có evidence sandbox, legacy revoke, client/device, key-ring/load và duyệt của owner. Rà riêng media booking/selfie/checklist/support/medical trước go/no-go toàn dự án. Người được phép xem vẫn có thể lưu/chụp ảnh; no-store không phải DRM và không thu hồi được bản đã tải.
