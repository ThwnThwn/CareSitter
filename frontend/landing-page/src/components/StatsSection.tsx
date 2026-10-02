const stats = [
  { value: "100%", label: "Hồ sơ được xác minh" },
  { value: "< 10 phút", label: "Thời gian kết nối trung bình" },
  { value: "4,9/5", label: "Điểm hài lòng của gia đình" },
  { value: "24/7", label: "Kênh hỗ trợ trong ca" },
];

export default function StatsSection() {
  return (
    <section className="stats-strip" aria-label="Các cam kết của CareSitter">
      <div className="shell stats-strip__grid">
        {stats.map((stat) => (
          <div className="stat" data-scroll-reveal="item" key={stat.label}>
            <strong>{stat.value}</strong>
            <span>{stat.label}</span>
          </div>
        ))}
      </div>
    </section>
  );
}
