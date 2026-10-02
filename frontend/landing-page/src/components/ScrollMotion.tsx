"use client";

import { useEffect } from "react";
import Lenis from "lenis";
import "lenis/dist/lenis.css";

const ease = "cubic-bezier(0.16, 1, 0.3, 1)";

/** MedScan-style smooth scrolling and once-only viewport entrances. */
export default function ScrollMotion() {
  useEffect(() => {
    const lenis = new Lenis({
      autoRaf: true,
      lerp: 0.1,
      anchors: { force: true },
      // The landing page explicitly opts into continuous motion.
      respectReducedMotion: false,
      prevent: (node) => Boolean(node.closest('[role="dialog"], .mobile-nav')),
    });
    const syncScrollLock = () => {
      const locked = document.body.style.overflow === "hidden"
        || document.body.classList.contains("menu-is-open");
      if (locked) lenis.stop();
      else lenis.start();
    };
    const bodyObserver = new MutationObserver(syncScrollLock);
    bodyObserver.observe(document.body, { attributes: true, attributeFilter: ["class", "style"] });
    syncScrollLock();

    const animations = new Set<Animation>();
    const pending = new Set<Element>();
    const play = (element: Element) => {
      const heading = element.getAttribute("data-scroll-reveal") === "heading";
      const targets = heading ? Array.from(element.querySelectorAll(".motion-word")) : [element];
      targets.forEach((target, index) => {
        const distance = element.getAttribute("data-scroll-reveal") === "item" ? 36 : 150;
        const animation = target.animate(
          heading
            ? [
                { opacity: 0.001, filter: "blur(10px)", transform: "translateY(10px)" },
                { opacity: 1, filter: "blur(0px)", transform: "translateY(0)" },
              ]
            : [
                { opacity: 0, translate: `0 ${distance}px` },
                { opacity: 1, translate: "0 0" },
              ],
          { duration: heading ? 500 : distance === 36 ? 650 : 1100,
            delay: heading ? index * 50 : 0, easing: ease, fill: "backwards" },
        );
        animations.add(animation);
        animation.onfinish = () => { animations.delete(animation); animation.cancel(); };
      });
    };
    const flush = () => {
      if (document.visibilityState !== "visible") return;
      for (const element of pending) play(element);
      pending.clear();
    };
    const observer = "IntersectionObserver" in window ? new IntersectionObserver((entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) { pending.delete(entry.target); continue; }
        pending.add(entry.target);
        observer?.unobserve(entry.target);
      }
      flush();
    }, { threshold: 0, rootMargin: "0px 0px -24px 0px" }) : null;

    document.querySelectorAll<HTMLElement>("[data-scroll-reveal]").forEach((element) => {
      // Keep restored/deep-linked content readable, and the SSR fallback visible.
      if (element.getBoundingClientRect().bottom > 0) observer?.observe(element);
    });
    const finishFocused = (event: FocusEvent) => {
      for (const animation of animations) {
        const target = (animation.effect as KeyframeEffect | null)?.target;
        if (target instanceof Element && event.target instanceof Node && target.contains(event.target)) animation.finish();
      }
    };
    document.addEventListener("visibilitychange", flush);
    document.addEventListener("focusin", finishFocused);
    return () => {
      observer?.disconnect();
      bodyObserver.disconnect();
      document.removeEventListener("visibilitychange", flush);
      document.removeEventListener("focusin", finishFocused);
      animations.forEach((animation) => animation.cancel());
      lenis.destroy();
    };
  }, []);
  return null;
}
