"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
import Link from "next/link";
import { ArrowUpRight, ClipboardCheck } from "lucide-react";
import { serviceGroups } from "@/lib/service-catalog";

interface InterestDraft {
  name: string;
  phone: string;
  area: string;
  service: string;
  experience: string;
  training: string;
  email: string;
  note: string;
}

export default function CaregiverInterestPreview() {
  const [draft, setDraft] = useState<InterestDraft | null>(null);
  const [reviewing, setReviewing] = useState(false);
  const review = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (reviewing) review.current?.focus();
  }, [reviewing]);

  function preview(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const read = (name: string) => String(form.get(name) ?? "").trim();
    setDraft({
      name: read("name"),
      phone: read("phone"),
      area: read("area"),
      service: read("service"),
      experience: read("experience"),
      training: read("training"),
      email: read("email"),
      note: read("note"),
    });
    setReviewing(true);
  }

  return (
    <div className="interest-panel">
      <div className="preview-notice">
        <strong>Biểu mẫu xem thử</strong>
        <p>
          Thông tin chỉ hiển thị trên thiết bị của bạn trong lượt xem này. Kênh
          tiếp nhận chính thức sẽ được công bố khi CareSitter hoàn tất quy trình
          tiếp nhận và xét duyệt hồ sơ.
        </p>
      </div>
      {reviewing && draft ? (
        <div className="interest-review" ref={review} tabIndex={-1}>
          <ClipboardCheck size={32} aria-hidden="true" />
          <h3>Xem lại thông tin của bạn</h3>
          <p>Bản xem trước giúp bạn hình dung bước đăng ký tham gia.</p>
          <dl>
            {[
              ["Họ và tên", draft.name],
              ["Điện thoại", draft.phone],
              ["Khu vực mong muốn", draft.area],
              ["Nhóm công việc", draft.service],
              ["Kinh nghiệm", draft.experience],
              ["Đào tạo", draft.training],
              ["Email", draft.email || "Chưa cung cấp"],
              ["Lời nhắn", draft.note || "Chưa cung cấp"],
            ].map(([label, value]) => (
              <div key={label}>
                <dt>{label}</dt>
                <dd>{value}</dd>
              </div>
            ))}
          </dl>
          <p className="interest-review__note">
            Thông tin đang được xem thử và chưa được gửi đến CareSitter.
          </p>
          <button
            className="button button--primary"
            onClick={() => setReviewing(false)}
          >
            Chỉnh sửa thông tin
          </button>
        </div>
      ) : (
        <form className="interest-form" onSubmit={preview}>
          <div className="interest-form__row">
            <label>
              Họ và tên <span aria-hidden="true">*</span>
              <input
                name="name"
                autoComplete="name"
                required
                minLength={2}
                maxLength={120}
                defaultValue={draft?.name}
              />
            </label>
            <label>
              Số điện thoại <span aria-hidden="true">*</span>
              <input
                name="phone"
                type="tel"
                inputMode="tel"
                autoComplete="tel"
                required
                pattern="0[35789][0-9]{8}"
                maxLength={10}
                placeholder="Ví dụ 0912345678"
                title="Nhập số điện thoại Việt Nam gồm 10 chữ số, bắt đầu bằng 03, 05, 07, 08 hoặc 09"
                defaultValue={draft?.phone}
              />
            </label>
          </div>
          <label>
            Khu vực muốn làm việc <span aria-hidden="true">*</span>
            <input
              name="area"
              autoComplete="address-level2"
              required
              minLength={2}
              maxLength={160}
              placeholder="Quận/huyện và tỉnh/thành"
              defaultValue={draft?.area}
            />
            <small>
              Khu vực phục vụ thực tế sẽ được trao đổi khi tiếp nhận.
            </small>
          </label>
          <label>
            Nhóm công việc quan tâm <span aria-hidden="true">*</span>
            <select name="service" required defaultValue={draft?.service ?? ""}>
              <option value="" disabled>
                Chọn nhóm công việc
              </option>
              {serviceGroups.map((group) => (
                <option key={group.code} value={group.name}>
                  {group.name}
                </option>
              ))}
            </select>
          </label>
          <div className="interest-form__row">
            <label>
              Kinh nghiệm chăm sóc <span aria-hidden="true">*</span>
              <select
                name="experience"
                required
                defaultValue={draft?.experience ?? ""}
              >
                <option value="" disabled>
                  Chọn kinh nghiệm
                </option>
                {[
                  "Chưa có kinh nghiệm",
                  "Dưới 1 năm",
                  "Từ 1 đến 3 năm",
                  "Trên 3 năm",
                ].map((value) => (
                  <option key={value}>{value}</option>
                ))}
              </select>
            </label>
            <label>
              Nhu cầu đào tạo
              <select
                name="training"
                defaultValue={draft?.training ?? "Muốn được tư vấn lộ trình"}
              >
                {[
                  "Muốn được tư vấn lộ trình",
                  "Muốn học thêm kỹ năng",
                  "Đã có chuyên môn, muốn được đánh giá",
                ].map((value) => (
                  <option key={value}>{value}</option>
                ))}
              </select>
            </label>
          </div>
          <label>
            Email (tùy chọn)
            <input
              name="email"
              type="email"
              autoComplete="email"
              maxLength={160}
              defaultValue={draft?.email}
            />
          </label>
          <label>
            Lời nhắn (tùy chọn)
            <textarea
              name="note"
              rows={3}
              maxLength={1000}
              placeholder="Chia sẻ ngắn về kinh nghiệm hoặc mong muốn của bạn"
              defaultValue={draft?.note}
            />
          </label>
          <label className="interest-consent">
            <input name="consent" type="checkbox" required />
            <span>
              Tôi đã đọc thông tin về quy trình tham gia và{" "}
              <Link href="/privacy">chính sách quyền riêng tư</Link>.
            </span>
          </label>
          <button className="button button--primary" type="submit">
            Xem lại thông tin
            <ArrowUpRight size={18} aria-hidden="true" />
          </button>
        </form>
      )}
    </div>
  );
}
