import Image from "next/image";

export default function AboutSection() {
  return (
    <section className="about-section" id="about">
      <div className="shell">
        <div className="about-grid">
          <div className="about-photo">
            <Image
              src="/images/app-hero.jpg"
              alt="Sự đồng hành giữa người chăm sóc và gia đình"
              fill
              sizes="(max-width: 800px) 100vw, 42vw"
            />
            <span>Mỗi sự chăm sóc đều bắt đầu từ sự thấu hiểu.</span>
          </div>
          <div className="about-story">
            <p className="section-label section-label--ink">Về chúng tôi</p>
            <h2 className="display display--section">
              Kết nối sự chăm sóc,
              <br />
              <em>vun đắp sự an tâm.</em>
            </h2>
            <p>
              CareSitter là nền tảng kết nối gia đình có nhu cầu chăm sóc người
              thân với những người chăm sóc phù hợp. Chúng tôi giúp gia đình
              tiếp cận thông tin, lựa chọn dịch vụ và theo dõi quá trình chăm
              sóc thuận tiện hơn, đồng thời mở thêm cơ hội làm việc và phát
              triển nghề nghiệp cho người chăm sóc.
            </p>
            <h3>Câu chuyện hình thành</h3>
            <p>
              CareSitter bắt đầu từ những khó khăn rất gần gũi. Khi cha mẹ, ông
              bà hoặc người thân cần hỗ trợ, gia đình thường có nhiều băn khoăn
              về kinh nghiệm, kỹ năng và sự tin cậy của người chăm sóc.
            </p>
            <p>
              Ở phía người chăm sóc, những người tâm huyết với nghề cũng cần cơ
              hội tiếp cận công việc, thể hiện năng lực và xây dựng uy tín.
            </p>
            <p>
              Chúng tôi xây dựng CareSitter để kết nối hai phía trong một môi
              trường chăm sóc minh bạch, thuận tiện và đáng tin cậy.
            </p>
          </div>
        </div>
        <div className="purpose-grid">
          <article>
            <span>01 / Sứ mệnh</span>
            <h3>
              An tâm cho gia đình.
              <br />
              Cơ hội cho người chăm sóc.
            </h3>
            <p>
              Giúp mỗi gia đình an tâm hơn khi người thân được chăm sóc, đồng
              thời tạo thêm cơ hội phát triển cho những người lựa chọn chăm sóc
              như một nghề nghiệp có giá trị.
            </p>
          </article>
          <article>
            <span>02 / Tầm nhìn</span>
            <h3>
              Một cộng đồng chăm sóc
              <br />
              được xây bằng niềm tin.
            </h3>
            <p>
              Trở thành nền tảng kết nối chăm sóc tại nhà được gia đình và người
              chăm sóc tin cậy, góp phần xây dựng một cộng đồng chuyên nghiệp,
              minh bạch và nhân văn.
            </p>
          </article>
        </div>
      </div>
    </section>
  );
}
