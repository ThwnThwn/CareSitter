"use client";

import {
  ArrowUpRight,
  Check,
  HeartHandshake,
  Leaf,
  Sparkles,
} from "lucide-react";
import { useConsultation } from "@/features/consultation/ConsultationProvider";
import {
  carePackages,
  formatVnd,
  packagePrices,
  serviceGroups,
} from "@/lib/service-catalog";

const packageIcons = [HeartHandshake, Leaf, Sparkles];

export default function ServiceCatalogSection() {
  const openConsultation = useConsultation();
  return (
    <section className="catalog-section" id="services">
      <div className="shell">
        <div className="section-intro">
          <div>
            <p className="section-label section-label--ink">
              Chăm sóc theo điều gia đình cần
            </p>
            <h2 className="display display--section">
              Mỗi người thân,
              <br />
              <em>một nhu cầu chăm sóc.</em>
            </h2>
          </div>
          <p>
            Ba dòng gói dành cho người cao tuổi, người bệnh hoặc người khuyết
            tật, được tư vấn theo nhu cầu và phạm vi phục vụ phù hợp.
          </p>
        </div>
        <div className="package-grid">
          {carePackages.map((item, index) => {
            const Icon = packageIcons[index];
            return (
              <article
                className={`package-card${item.featured ? " package-card--featured" : ""}`}
                key={item.name}
              >
                <div className="package-card__top">
                  <Icon size={26} aria-hidden="true" />
                  <span>{item.groups}</span>
                </div>
                <p className="package-card__brand">CareSitter</p>
                <h3>{item.name}</h3>
                <strong className="package-card__scope">{item.scope}</strong>
                <p>{item.description}</p>
                <div className="package-card__price">
                  <small>{item.note}</small>
                  <strong>
                    {item.price === null
                      ? "Theo tư vấn"
                      : formatVnd(item.price)}
                  </strong>
                </div>
                <button
                  className={`button ${item.featured ? "button--light" : "button--primary"}`}
                  onClick={() =>
                    openConsultation(undefined, `CareSitter ${item.name}`)
                  }
                >
                  Tư vấn gói {item.name}
                  <ArrowUpRight size={17} aria-hidden="true" />
                </button>
              </article>
            );
          })}
        </div>
        <p className="catalog-note">
          <Check size={17} aria-hidden="true" /> Thời lượng mỗi buổi và phạm vi
          thực hiện được xác nhận khi tư vấn. Công việc điều dưỡng và chuyên
          biệt cần được đánh giá, xác nhận đơn vị thực hiện và người có chuyên
          môn phù hợp.
        </p>
        <details className="catalog-details">
          <summary>
            <span>
              <small>01 / Danh mục chi tiết</small>Khám phá 12 dịch vụ thành
              phần
            </span>
            <span className="details-symbol" aria-hidden="true">
              +
            </span>
          </summary>
          <div className="service-group-grid">
            {serviceGroups.map((group) => (
              <div className="service-group" key={group.code}>
                <h3>
                  <span>{group.code}</span>
                  {group.name}
                </h3>
                <ul>
                  {group.services.map((service) => (
                    <li key={service.name}>
                      <span>{service.name}</span>
                      <strong>
                        {formatVnd(service.hourlyPrice)}
                        <small>/giờ</small>
                      </strong>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
          <p className="catalog-note">
            Giá niêm yết theo thông tin kinh doanh hiệu lực 01/10/2026. Mức phí
            và điều kiện áp dụng được xác nhận trước khi đặt dịch vụ.
          </p>
        </details>
        <details className="catalog-details">
          <summary>
            <span>
              <small>02 / Lựa chọn định kỳ</small>Bảng giá An Nhiên & An Khang
            </span>
            <span className="details-symbol" aria-hidden="true">
              +
            </span>
          </summary>
          <div
            className="price-table-scroll"
            role="region"
            aria-label="Bảng giá gói chăm sóc"
            tabIndex={0}
          >
            <table className="price-table">
              <caption>
                Đơn vị đồng/gói. Lịch 2–6 ngày/tuần tính theo 4 tuần, gói tháng
                gồm 30 buổi.
              </caption>
              <thead>
                <tr>
                  <th scope="col">Lựa chọn</th>
                  <th scope="col">Số buổi</th>
                  <th scope="col">An Nhiên</th>
                  <th scope="col">An Khang</th>
                </tr>
              </thead>
              <tbody>
                {packagePrices.map((row) => (
                  <tr key={row.label}>
                    <th scope="row">{row.label}</th>
                    <td>{row.sessions}</td>
                    <td>{formatVnd(row.anNhien)}</td>
                    <td>{formatVnd(row.anKhang)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="catalog-note">
            Gói Thân Trí được tư vấn riêng về dịch vụ, số buổi và thời lượng phù
            hợp.
          </p>
        </details>
      </div>
    </section>
  );
}
