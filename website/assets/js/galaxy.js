/*
 * BeatFinder — starfield & galaxy particle background.
 * Lightweight canvas animation: twinkling stars, drifting galaxy dust,
 * and occasional shooting stars. Respects prefers-reduced-motion.
 */
(function () {
  "use strict";

  const canvas = document.getElementById("starfield");
  if (!canvas) return;

  const ctx = canvas.getContext("2d");
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  let width, height, dpr;
  let stars = [];
  let dust = [];
  let shooting = [];

  const STAR_COLORS = ["#ffffff", "#cfe9ff", "#e2d4ff", "#ffd9f2"];

  function resize() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    width = window.innerWidth;
    height = window.innerHeight;
    canvas.width = width * dpr;
    canvas.height = height * dpr;
    canvas.style.width = width + "px";
    canvas.style.height = height + "px";
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    seed();
  }

  function seed() {
    const starCount = Math.min(240, Math.floor((width * height) / 6500));
    stars = Array.from({ length: starCount }, () => ({
      x: Math.random() * width,
      y: Math.random() * height,
      r: Math.random() * 1.4 + 0.3,
      color: STAR_COLORS[(Math.random() * STAR_COLORS.length) | 0],
      phase: Math.random() * Math.PI * 2,
      speed: Math.random() * 0.9 + 0.35,
    }));

    const dustCount = Math.min(46, Math.floor((width * height) / 34000));
    dust = Array.from({ length: dustCount }, () => ({
      x: Math.random() * width,
      y: Math.random() * height,
      r: Math.random() * 2.2 + 0.8,
      vx: (Math.random() - 0.5) * 0.12,
      vy: (Math.random() - 0.5) * 0.08,
      hue: Math.random() < 0.5 ? "123, 47, 247" : "0, 229, 255",
      alpha: Math.random() * 0.35 + 0.1,
    }));
  }

  function spawnShootingStar() {
    if (shooting.length > 2) return;
    const fromLeft = Math.random() < 0.5;
    shooting.push({
      x: fromLeft ? -40 : Math.random() * width,
      y: Math.random() * height * 0.4,
      vx: 7 + Math.random() * 5,
      vy: 2.4 + Math.random() * 2,
      life: 1,
    });
  }

  let t = 0;
  function frame() {
    t += 0.016;
    ctx.clearRect(0, 0, width, height);

    // Twinkling stars
    for (const s of stars) {
      const tw = 0.55 + 0.45 * Math.sin(t * s.speed * 2 + s.phase);
      ctx.globalAlpha = tw;
      ctx.fillStyle = s.color;
      ctx.beginPath();
      ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2);
      ctx.fill();
    }

    // Drifting nebula dust
    for (const d of dust) {
      d.x += d.vx;
      d.y += d.vy;
      if (d.x < -10) d.x = width + 10;
      if (d.x > width + 10) d.x = -10;
      if (d.y < -10) d.y = height + 10;
      if (d.y > height + 10) d.y = -10;
      const g = ctx.createRadialGradient(d.x, d.y, 0, d.x, d.y, d.r * 4);
      g.addColorStop(0, "rgba(" + d.hue + "," + d.alpha + ")");
      g.addColorStop(1, "rgba(" + d.hue + ",0)");
      ctx.globalAlpha = 1;
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(d.x, d.y, d.r * 4, 0, Math.PI * 2);
      ctx.fill();
    }

    // Shooting stars
    for (let i = shooting.length - 1; i >= 0; i--) {
      const m = shooting[i];
      m.x += m.vx;
      m.y += m.vy;
      m.life -= 0.014;
      if (m.life <= 0 || m.x > width + 60 || m.y > height + 60) {
        shooting.splice(i, 1);
        continue;
      }
      const tail = 90;
      const grad = ctx.createLinearGradient(m.x, m.y, m.x - m.vx * tail * 0.12, m.y - m.vy * tail * 0.12);
      grad.addColorStop(0, "rgba(255,255,255," + 0.9 * m.life + ")");
      grad.addColorStop(1, "rgba(0,229,255,0)");
      ctx.globalAlpha = 1;
      ctx.strokeStyle = grad;
      ctx.lineWidth = 1.6;
      ctx.beginPath();
      ctx.moveTo(m.x, m.y);
      ctx.lineTo(m.x - m.vx * tail * 0.12, m.y - m.vy * tail * 0.12);
      ctx.stroke();
    }

    ctx.globalAlpha = 1;
    requestAnimationFrame(frame);
  }

  function drawStatic() {
    ctx.clearRect(0, 0, width, height);
    for (const s of stars) {
      ctx.globalAlpha = 0.8;
      ctx.fillStyle = s.color;
      ctx.beginPath();
      ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  window.addEventListener("resize", () => {
    resize();
    if (reduceMotion) drawStatic();
  });

  resize();

  if (reduceMotion) {
    drawStatic();
  } else {
    requestAnimationFrame(frame);
    setInterval(spawnShootingStar, 4200);
  }
})();
