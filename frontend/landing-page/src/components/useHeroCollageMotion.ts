"use client";

import { animate, type JSAnimation } from "animejs";
import { useEffect, type RefObject } from "react";

/** A once-only photo entrance, with small independent movements for its layers. */
export function useHeroCollageMotion(heroRef: RefObject<HTMLElement | null>) {
  useEffect(() => {
    const collage = heroRef.current?.querySelector<HTMLElement>(".hero-collage");
    if (!collage) return;

    const photo = collage.querySelector<HTMLImageElement>(".hero-collage__main img");
    const finePointer = window.matchMedia("(hover: hover) and (pointer: fine)");
    const animations = new Set<JSAnimation>();
    let inView = !("IntersectionObserver" in window);
    let entered = false;
    let pointerFrame = 0;
    let pointerX = 0;
    let pointerY = 0;

    const canMove = () => inView && !document.hidden;
    const resetPointer = () => {
      window.cancelAnimationFrame(pointerFrame);
      pointerFrame = 0;
      collage.style.removeProperty("--hero-pointer-x");
      collage.style.removeProperty("--hero-pointer-y");
    };

    const enter = () => {
      entered = true;
      const compact = window.matchMedia("(max-width: 820px)").matches;
      const amplitude = compact ? 0.55 : 1;
      const layers = [
        { name: "main", x: 0, y: 36, angle: -1.2, delay: 120, drift: 0 },
        { name: "portrait", x: 22, y: -18, angle: 4, delay: 260, drift: -6 },
        { name: "seal", x: -24, y: 8, angle: -2, delay: 430, drift: -4 },
        { name: "caption", x: 18, y: 26, angle: 2, delay: 570, drift: 5 },
      ];

      layers.forEach((layer, index) => {
        const element = collage.querySelector<HTMLElement>(`.hero-collage__${layer.name}`);
        if (!element) return;
        const entrance = animate(element, {
          translateX: [layer.x * amplitude, 0],
          translateY: [layer.y * amplitude, 0],
          rotate: [layer.angle * amplitude, 0],
          scale: [0.97, 1],
          duration: 1100,
          delay: layer.delay,
          ease: "outExpo",
          onComplete: (animation) => {
            animations.delete(animation);
            animation.revert();
            if (!layer.drift) return;
            const drift = animate(element, {
              translateY: [0, layer.drift * amplitude],
              duration: 2900 + index * 450,
              alternate: true,
              loop: true,
              ease: "inOutSine",
              autoplay: canMove(),
            });
            animations.add(drift);
          },
        });
        animations.add(entrance);
      });

      if (photo) {
        const focus = animate(photo, {
          scale: [1.045, 1],
          duration: 1700,
          ease: "outQuint",
          onComplete: (animation) => {
            animations.delete(animation);
            animation.revert();
          },
        });
        animations.add(focus);
      }
    };

    const sync = () => {
      if (canMove() && !entered && (!photo || photo.complete)) enter();
      animations.forEach((animation) => {
        if (canMove()) animation.resume();
        else animation.pause();
      });
      if (!canMove() || !finePointer.matches) resetPointer();
    };

    const observer = "IntersectionObserver" in window
      ? new IntersectionObserver(([entry]) => {
          inView = entry.isIntersecting;
          sync();
        }, { threshold: 0.08 })
      : null;

    const onPointerMove = (event: PointerEvent) => {
      if (!canMove() || !finePointer.matches || event.pointerType === "touch") return;
      const bounds = collage.getBoundingClientRect();
      pointerX = Math.max(-1, Math.min(1, (event.clientX - bounds.left) / bounds.width * 2 - 1)) * 7;
      pointerY = Math.max(-1, Math.min(1, (event.clientY - bounds.top) / bounds.height * 2 - 1)) * 7;
      if (pointerFrame) return;
      pointerFrame = window.requestAnimationFrame(() => {
        collage.style.setProperty("--hero-pointer-x", `${pointerX.toFixed(2)}px`);
        collage.style.setProperty("--hero-pointer-y", `${pointerY.toFixed(2)}px`);
        pointerFrame = 0;
      });
    };

    observer?.observe(collage);
    photo?.addEventListener("load", sync);
    photo?.addEventListener("error", sync);
    collage.addEventListener("pointermove", onPointerMove, { passive: true });
    collage.addEventListener("pointerleave", resetPointer);
    document.addEventListener("visibilitychange", sync);
    finePointer.addEventListener("change", sync);
    sync();

    return () => {
      observer?.disconnect();
      photo?.removeEventListener("load", sync);
      photo?.removeEventListener("error", sync);
      collage.removeEventListener("pointermove", onPointerMove);
      collage.removeEventListener("pointerleave", resetPointer);
      document.removeEventListener("visibilitychange", sync);
      finePointer.removeEventListener("change", sync);
      animations.forEach((animation) => animation.revert());
      resetPointer();
    };
  }, [heroRef]);
}
