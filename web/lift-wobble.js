(function () {
  function seededRandom(seed) {
    let state = seed >>> 0;
    return function next() {
      state = (1664525 * state + 1013904223) >>> 0;
      return state / 4294967296;
    };
  }

  function applyWobble(el) {
    const text = el.dataset.text || el.textContent || "";
    const seed = Number.parseInt(el.dataset.seed || "42", 10);
    const maxOffset = Number.parseFloat(el.dataset.maxOffset || "2");
    const maxRotate = Number.parseFloat(el.dataset.maxRotate || "0.1");
    const rng = seededRandom(seed);

    el.textContent = "";
    for (const ch of text) {
      const span = document.createElement("span");
      span.style.display = "inline-block";
      span.textContent = ch === " " ? "\u00A0" : ch;

      const dx = (rng() * 2 - 1) * maxOffset;
      const dy = (rng() * 2 - 1) * maxOffset;
      const angle = (rng() * 2 - 1) * maxRotate;
      span.style.transform = "translate(" + dx.toFixed(2) + "px, " + dy.toFixed(2) + "px) rotate(" + angle.toFixed(3) + "rad)";

      el.appendChild(span);
    }
  }

  function applyWobbleText(selector) {
    const targetSelector = selector || '[data-wobbly="true"]';
    document.querySelectorAll(targetSelector).forEach(applyWobble);
  }

  window.applyWobbleText = applyWobbleText;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () {
      applyWobbleText();
    });
  } else {
    applyWobbleText();
  }
})();
