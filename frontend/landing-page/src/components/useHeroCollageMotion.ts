"use client";

import { useGSAP } from "@gsap/react";
import { gsap } from "gsap";
import type { RefObject } from "react";

gsap.registerPlugin(useGSAP);

/** Choreographs the reassurance journey and adds restrained pointer depth. */
export function useHeroCollageMotion(heroRef: RefObject<HTMLElement | null>) {
  useGSAP(
    () => {
      const hero = heroRef.current;
      const journey = hero?.querySelector<HTMLElement>(".hero-journey");
      if (!hero || !journey) return;

      const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
      if (reducedMotion.matches) return;

      const finePointer = window.matchMedia("(hover: hover) and (pointer: fine)");
      const photo = journey.querySelector<HTMLElement>(".hero-journey__photo img");
      const portrait = journey.querySelector<HTMLElement>(".hero-journey__portrait");
      const line = journey.querySelector<SVGPathElement>(".hero-journey__path-line");
      const layers = gsap.utils.toArray<HTMLElement>("[data-journey-layer]", journey);
      const cards = gsap.utils.toArray<HTMLElement>("[data-journey-card]", journey);

      gsap.set(line, { strokeDashoffset: 1 });

      const entrance = gsap.timeline({ defaults: { ease: "power3.out" } });
      entrance
        .fromTo(
          photo,
          { autoAlpha: 0, scale: 1.065 },
          { autoAlpha: 1, duration: 1.15, scale: 1.015 },
        )
        .fromTo(
          portrait,
          { autoAlpha: 0, y: -28 },
          { autoAlpha: 1, duration: 0.72, y: 0 },
          0.18,
        )
        .to(line, { duration: 1.35, ease: "power2.inOut", strokeDashoffset: 0 }, 0.42)
        .fromTo(
          cards,
          { autoAlpha: 0, x: 18, y: 12 },
          {
            autoAlpha: 1,
            duration: 0.62,
            stagger: 0.2,
            x: 0,
            y: 0,
          },
          0.58,
        );

      const layerMotion = layers.map((layer) => {
        const depth = Number(layer.dataset.depth ?? 1);
        return {
          xTo: gsap.quickTo(layer, "x", { duration: 0.65, ease: "power3.out" }),
          yTo: gsap.quickTo(layer, "y", { duration: 0.65, ease: "power3.out" }),
          depth,
        };
      });

      const resetPointer = () => {
        layerMotion.forEach(({ xTo, yTo }) => {
          xTo(0);
          yTo(0);
        });
      };

      const onPointerMove = (event: PointerEvent) => {
        if (!finePointer.matches || event.pointerType === "touch") return;
        const bounds = journey.getBoundingClientRect();
        const x = gsap.utils.clamp(-1, 1, (event.clientX - bounds.left) / bounds.width * 2 - 1);
        const y = gsap.utils.clamp(-1, 1, (event.clientY - bounds.top) / bounds.height * 2 - 1);

        layerMotion.forEach(({ xTo, yTo, depth }) => {
          xTo(x * depth * 5.5);
          yTo(y * depth * 4.5);
        });
      };

      const photoScaleTo = photo
        ? gsap.quickTo(photo, "scale", { duration: 0.45, ease: "power2.out" })
        : null;
      let scrollFrame = 0;

      const syncScroll = () => {
        scrollFrame = 0;
        if (!photoScaleTo) return;
        const bounds = journey.getBoundingClientRect();
        const progress = gsap.utils.clamp(0, 1, -bounds.top / Math.max(bounds.height, 1));
        photoScaleTo(1.015 + progress * 0.045);
      };

      const onScroll = () => {
        if (scrollFrame) return;
        scrollFrame = window.requestAnimationFrame(syncScroll);
      };

      journey.addEventListener("pointermove", onPointerMove, { passive: true });
      journey.addEventListener("pointerleave", resetPointer);
      finePointer.addEventListener("change", resetPointer);
      window.addEventListener("scroll", onScroll, { passive: true });

      return () => {
        journey.removeEventListener("pointermove", onPointerMove);
        journey.removeEventListener("pointerleave", resetPointer);
        finePointer.removeEventListener("change", resetPointer);
        window.removeEventListener("scroll", onScroll);
        window.cancelAnimationFrame(scrollFrame);
      };
    },
    { scope: heroRef },
  );
}
