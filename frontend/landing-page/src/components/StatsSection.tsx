'use client';

import React, { useEffect, useState, useRef } from 'react';

export default function StatsSection() {
  const [isVisible, setIsVisible] = useState(false);
  const sectionRef = useRef<HTMLDivElement>(null);

  const [count1, setCount1] = useState(0);
  const [count2, setCount2] = useState(0);
  const [count3, setCount3] = useState(0);
  const [count4, setCount4] = useState(0);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) {
          setIsVisible(true);
        }
      },
      { threshold: 0.2 }
    );

    if (sectionRef.current) {
      observer.observe(sectionRef.current);
    }

    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!isVisible) return;

    // Animate stats
    const duration = 2000;
    const steps = 50;
    const intervalTime = duration / steps;
    let step = 0;

    const timer = setInterval(() => {
      step++;
      const progress = step / steps;
      setCount1(Math.floor(50000 * progress));
      setCount2(parseFloat((4.9 * progress).toFixed(1)));
      setCount3(Math.floor(10 * progress));
      setCount4(Math.floor(98 * progress));

      if (step >= steps) {
        setCount1(50000);
        setCount2(4.9);
        setCount3(10);
        setCount4(98);
        clearInterval(timer);
      }
    }, intervalTime);

    return () => clearInterval(timer);
  }, [isVisible]);

  return (
    <section ref={sectionRef} id="stats" className="py-14 border-y border-[#D1FAE5] bg-[#F0FDF4] relative z-20">
      <div className="max-w-7xl mx-auto px-6">
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-8 lg:gap-12">

          {/* Stat 1 */}
          <div className="flex flex-col items-center text-center p-4">
            <div className="font-headline font-extrabold text-4xl sm:text-5xl lg:text-6xl text-[#00B14F] tracking-tight">
              {count1.toLocaleString('vi-VN')}+
            </div>
            <div className="text-sm sm:text-base text-[#4A6B5D] font-semibold mt-2">
              Verified Caregivers
            </div>
          </div>

          {/* Stat 2 */}
          <div className="flex flex-col items-center text-center p-4">
            <div className="font-headline font-extrabold text-4xl sm:text-5xl lg:text-6xl text-[#0F291E] tracking-tight flex items-center justify-center">
              <span>{count2.toFixed(1)}</span>
              <span className="text-amber-500 ml-1">★</span>
            </div>
            <div className="text-sm sm:text-base text-[#4A6B5D] font-semibold mt-2">
              Average Rating
            </div>
          </div>

          {/* Stat 3 */}
          <div className="flex flex-col items-center text-center p-4">
            <div className="font-headline font-extrabold text-4xl sm:text-5xl lg:text-6xl text-[#00B14F] tracking-tight">
              &lt; {count3} min
            </div>
            <div className="text-sm sm:text-base text-[#4A6B5D] font-semibold mt-2">
              Average Match Time
            </div>
          </div>

          {/* Stat 4 */}
          <div className="flex flex-col items-center text-center p-4">
            <div className="font-headline font-extrabold text-4xl sm:text-5xl lg:text-6xl text-[#00B14F] tracking-tight">
              {count4}%
            </div>
            <div className="text-sm sm:text-base text-[#4A6B5D] font-semibold mt-2">
              Families Satisfied
            </div>
          </div>

        </div>
      </div>
    </section>
  );
}
