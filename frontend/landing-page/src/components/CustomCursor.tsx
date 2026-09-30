'use client';

import React, { useEffect, useState } from 'react';

export default function CustomCursor() {
  const [position, setPosition] = useState({ x: -100, y: -100 });
  const [trailingPos, setTrailingPos] = useState({ x: -100, y: -100 });
  const [isHovering, setIsHovering] = useState(false);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    // Only enable on desktop with fine pointer
    if (window.matchMedia('(pointer: coarse)').matches) return;

    let animFrame: number;
    let targetX = -100;
    let targetY = -100;
    let currentX = -100;
    let currentY = -100;

    const handleMouseMove = (e: MouseEvent) => {
      targetX = e.clientX;
      targetY = e.clientY;
      setPosition({ x: targetX, y: targetY });
      if (!isVisible) setIsVisible(true);

      const target = e.target as HTMLElement | null;
      if (
        target?.closest('a') ||
        target?.closest('button') ||
        target?.closest('.hover-target') ||
        target?.closest('input') ||
        target?.closest('select')
      ) {
        setIsHovering(true);
      } else {
        setIsHovering(false);
      }
    };

    const handleMouseLeave = () => {
      setIsVisible(false);
    };

    const animate = () => {
      // Lerp for trailing ring
      currentX += (targetX - currentX) * 0.18;
      currentY += (targetY - currentY) * 0.18;
      setTrailingPos({ x: currentX, y: currentY });
      animFrame = requestAnimationFrame(animate);
    };

    window.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseleave', handleMouseLeave);
    animFrame = requestAnimationFrame(animate);

    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseleave', handleMouseLeave);
      cancelAnimationFrame(animFrame);
    };
  }, [isVisible]);

  if (!isVisible) return null;

  return (
    <>
      <div
        className={`custom-cursor-ring hidden md:block ${isHovering ? 'cursor-grow' : ''}`}
        style={{
          left: `${trailingPos.x}px`,
          top: `${trailingPos.y}px`,
        }}
      />
      <div
        className="custom-cursor-dot hidden md:block"
        style={{
          left: `${position.x}px`,
          top: `${position.y}px`,
        }}
      />
    </>
  );
}
