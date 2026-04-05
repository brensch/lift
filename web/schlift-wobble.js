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
    const rng = seededRandom(seed);

    el.textContent = "";
    for (const ch of text) {
      const span = document.createElement("span");
      span.classList.add("wobbly-letter");
      span.textContent = ch === " " ? "\u00A0" : ch;

      // Randomize animation duration and delay for a jumbled, slow look
      const duration = (10 + rng() * 8).toFixed(2);
      const delay = (rng() * -18).toFixed(2); // Negative delay to start mid-cycle
      span.style.animationDuration = duration + "s";
      span.style.animationDelay = delay + "s";

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
