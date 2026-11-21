// Drag-to-rotate turntable made of 36 renders of the Serona IoT casing (rendered in Fusion).
(function () {
  var elements = document.querySelectorAll("[data-turntable]");
  if (!elements.length) return;

  var count = 36;
  var base = "assets/casing/";
  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  var frames = [];
  for (var i = 0; i < count; i++) {
    var f = new Image();
    f.src = base + "frame-" + String(i).padStart(2, "0") + ".png";
    frames.push(f);
  }

  function init(el, start) {
    var img = el.querySelector("img");
    var index = start;
    var rafId = null;
    var dragging = false;
    var startX = 0;
    var startIndex = 0;

    function show(n) {
      index = ((Math.round(n) % count) + count) % count;
      img.src = frames[index].src;
    }

    function spin() {
      var last = performance.now();
      var acc = 0;
      function tick(now) {
        acc += now - last;
        last = now;
        if (acc > 110) {
          acc = 0;
          show(index + 1);
        }
        rafId = requestAnimationFrame(tick);
      }
      rafId = requestAnimationFrame(tick);
    }

    function stop() {
      if (rafId) cancelAnimationFrame(rafId);
      rafId = null;
    }

    function release() {
      if (!dragging) return;
      dragging = false;
      if (!reduceMotion) spin();
    }

    el.addEventListener("pointerdown", function (e) {
      dragging = true;
      startX = e.clientX;
      startIndex = index;
      stop();
      el.setPointerCapture(e.pointerId);
    });
    el.addEventListener("pointermove", function (e) {
      if (dragging) show(startIndex - (e.clientX - startX) / 12);
    });
    el.addEventListener("pointerup", release);
    el.addEventListener("pointercancel", release);
    el.addEventListener("keydown", function (e) {
      if (e.key === "ArrowLeft") { stop(); show(index - 1); e.preventDefault(); }
      if (e.key === "ArrowRight") { stop(); show(index + 1); e.preventDefault(); }
    });

    show(index);
    if (!reduceMotion) spin();
  }

  elements.forEach(function (el, n) {
    init(el, n === 0 ? 0 : 18);
  });
})();
