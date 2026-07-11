/*
 * BeatFinder — shared UI behavior: mobile nav, scroll reveal,
 * equalizer bar randomization, active nav link.
 */
(function () {
  "use strict";

  // Mobile navigation toggle
  const toggle = document.querySelector(".nav-toggle");
  const links = document.querySelector(".nav-links");
  if (toggle && links) {
    toggle.addEventListener("click", () => {
      const open = links.classList.toggle("open");
      toggle.setAttribute("aria-expanded", String(open));
    });
    links.addEventListener("click", (e) => {
      if (e.target.tagName === "A") links.classList.remove("open");
    });
  }

  // Highlight current page in nav
  const page = location.pathname.split("/").pop() || "index.html";
  document.querySelectorAll(".nav-links a").forEach((a) => {
    if (a.getAttribute("href") === page) a.classList.add("active");
  });

  // Reveal-on-scroll
  const revealables = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window && revealables.length) {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("visible");
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.12 }
    );
    revealables.forEach((el) => io.observe(el));
  } else {
    revealables.forEach((el) => el.classList.add("visible"));
  }

  // Randomize equalizer bar timings so the wave feels organic
  document.querySelectorAll(".equalizer span").forEach((bar) => {
    bar.style.animationDelay = (Math.random() * -1.1).toFixed(2) + "s";
    bar.style.animationDuration = (0.8 + Math.random() * 0.9).toFixed(2) + "s";
  });
})();
