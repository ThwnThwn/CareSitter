# Sửa hai check Phase 7 backend baseline

Cập nhật: 14/10/2026. PR [#34](https://github.com/ThwnThwn/CareSitter/pull/34), nhánh `develop`. Commit sửa: `56e1a4c39c1f1af8bef86379f12ce3b495a79874`. Tài liệu giữ local.

## Nguyên nhân đã xác minh

Hai check đỏ là cùng workflow backend chạy cho hai sự kiện `push` và `pull_request`, không phải hai lỗi nghiệp vụ độc lập.

- [Push trước sửa](https://github.com/ThwnThwn/CareSitter/actions/runs/38527241030/job/115730374509): 15 test fail, 319 pass, không skip.
- [PR trước sửa](https://github.com/ThwnThwn/CareSitter/actions/runs/38527653385/job/115731717082): 2 test fail, 332 pass, không skip.
- Tất cả lỗi có cùng `ManyServiceProvidersCreatedWarning`: EF giữ quá 20 internal service provider trong cache của process. Các fixture dùng People/Catalog tạo data source riêng cho DB/role test, nên Npgsql options tạo cache entry riêng; chúng tích lũy trong full suite. Thứ tự test khác nhau làm test gặp ngưỡng cũng khác nhau.
- Đã tái hiện local bằng toàn bộ Integration suite với PostgreSQL/PostGIS thật: 2 fail, 332 pass, không skip. Các bộ test nhỏ trước đó không đi qua đầy đủ chuỗi fixture để chạm ngưỡng này.

Nguồn kỹ thuật tham khảo: [cách Npgsql phân biệt cấu hình data source trong provider cache](https://github.com/npgsql/efcore.pg/blob/v8.0.11/src/EFCore.PG/Infrastructure/Internal/NpgsqlOptionsExtension.cs).

## Bản sửa

`TestEntityFrameworkServices.UseFixtureProvider<TContext>` đăng ký EF/Npgsql/NetTopologySuite vào DI container do fixture quản lý; bọc factory `DbContextOptions` gốc bằng `UseInternalServiceProvider` để container đó sở hữu/dispose dịch vụ EF. Giữ options và lifetime của module, dùng lại model giữa các scope của cùng fixture và tách dữ liệu/model giữa các fixture.

Áp dụng cho HealthProfile, SelfBeneficiary, KYC Media và Nearby Caregiver. Không đổi production registration hoặc nghiệp vụ, không bỏ test, không tắt warning/guard. Hai regression mới kiểm 30 data source độc lập, tái sử dụng model trong cùng fixture, DbContext riêng theo scope và connection/model tách giữa hai fixture.

Source: [helper](../../backend/tests/CareSitter.IntegrationTests/TestEntityFrameworkServices.cs), [regression](../../backend/tests/CareSitter.IntegrationTests/TestEntityFrameworkServicesTests.cs).

## Kiểm chứng local

Chạy cùng lệnh với backend CI:

```powershell
./backend/scripts/test-phase7.ps1 -Repeat 2 -SkipFrontend -ArtifactsDirectory backend/artifacts/ci-fix-20261014/baseline
```

| Kiểm tra | Kết quả |
| --- | --- |
| Hai regression mới | 2 pass |
| Phase 7 lượt 1 | **650/650 pass**, 0 fail/skip, 11 project test |
| Phase 7 lượt 2 | **650/650 pass**, 0 fail/skip, 11 project test |
| Integration trong mỗi lượt | **336/336 pass** |
| Kafka/Messaging trong mỗi lượt | **22/22 pass** |
| Migration DB mới, nâng DB cũ và replay | Pass cả hai lượt |
| Smoke API | Pass cả hai lượt |
| Source fingerprint | Không thay đổi trong đợt acceptance |

Môi trường Windows, .NET 8.0.425, Docker và PostGIS test riêng. Runner dọn đúng các container/thư mục tạm do nó tạo; không dùng DB ứng dụng hoặc container LMS hiện có. [Summary JSON](../../backend/artifacts/ci-fix-20261014/baseline/summary.json), [log](../../backend/artifacts/ci-fix-20261014/baseline.log).

## GitHub sau push

Bản sửa đã push lên `origin/develop` và cập nhật PR #34. Đã xác nhận hai run hoàn tất **success**, mỗi run 6/6 job xanh:

- [Backend push success](https://github.com/ThwnThwn/CareSitter/actions/runs/38530464048/job/115740848564).
- [Backend PR success](https://github.com/ThwnThwn/CareSitter/actions/runs/38530472721/job/115740877304).

AppHost, Nutrition, Customer, Caregiver và Admin cũng success trong cả hai run CI. Không merge PR hoặc deploy trong đợt sửa này. [Snapshot trạng thái CI](../../backend/artifacts/ci-fix-20261014/latest-ci-status.json).
