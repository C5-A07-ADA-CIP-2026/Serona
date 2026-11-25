// Interactive Serona demo: a dye bath weakens (even one dip can cross the limit), then the guided repair brings it back.
// The numbers are illustrative; nothing here reads a real sensor.
(function () {
  var $ = function (id) { return document.getElementById(id); };

  // Fading swatches for the story section (deep yellow -> lighter).
  var swatches = document.querySelector("[data-swatches]");
  if (swatches) {
    var from = [217, 164, 0];
    var to = [236, 205, 120];
    for (var i = 0; i < 15; i++) {
      var t = i / 14;
      var s = document.createElement("span");
      s.style.background = "rgb(" + from.map(function (c, k) { return Math.round(c + (to[k] - c) * t); }).join(",") + ")";
      swatches.appendChild(s);
    }
  }

  var device = $("simDevice");
  if (!device) return;

  var K_LIMIT = 90;
  var PH_LIMIT = 11.0;
  var PH_START = 11.5;
  var BATH_L = 20;
  var RECIPE_L = 15;
  var DYES = [["AS-OL", 35], ["AS-G", 12]];

  var el = {
    slider: $("simSlider"), output: $("simOutput"), reset: $("simReset"), status: $("simStatus"),
    bak: $("simBak"), pill: $("simPill"), tileK: $("simTileK"), tileP: $("simTileP"),
    fix: $("simFix"), doneStatic: $("simDoneStatic"),
    scrim: $("simScrim"), alert: $("simAlert"), alertClose: $("simAlertClose"), start: $("simStart"),
    repair: $("simRepair"), repairClose: $("simRepairClose"), repairTitle: $("simRepairTitle"),
    repairBody: $("simRepairBody"), next: $("simNext"), toast: $("simToast"), progress: $("simProgress")
  };

  var state = { drop: 0, phase: "monitor", dismissed: false, steps: [], step: 0, water: 0 };
  var toastTimer = null;

  function readings() {
    var c = state.drop / 100;
    return { k: 100 - 21 * c, ph: PH_START - 1.3 * c };
  }

  function fmtPh(v) { return v.toFixed(1).replace(".", ","); }

  function issue(r) {
    return { k: r.k < K_LIMIT, ph: r.ph < PH_LIMIT };
  }

  function announce(text) { el.status.textContent = text; }

  var lastFocus = null;

  function openSheet(which) {
    if (el.scrim.hidden) lastFocus = document.activeElement;
    el.scrim.hidden = false;
    el.alert.hidden = which !== "alert";
    el.repair.hidden = which !== "repair";
    var target = which === "alert" ? el.start : (el.next.disabled ? $("simPlus") || el.next : el.next);
    if (target) target.focus({ preventScroll: true });
  }

  function closeSheets(restore) {
    var wasOpen = !el.scrim.hidden;
    el.scrim.hidden = true;
    el.alert.hidden = true;
    el.repair.hidden = true;
    if (restore !== false && wasOpen) {
      var back = (!el.fix.hidden && el.fix) || el.slider;
      if (lastFocus && document.contains(lastFocus) && !lastFocus.disabled && lastFocus.offsetParent !== null) back = lastFocus;
      back.focus({ preventScroll: true });
    }
  }

  function render() {
    var r = readings();
    var low = issue(r);
    var bad = low.k || low.ph;

    el.output.textContent = state.drop ? "Turun " + state.drop + "%" : "Sesuai resep";
    el.tileK.querySelector("strong").textContent = Math.round(r.k) + "%";
    el.tileP.querySelector("strong").textContent = fmtPh(r.ph);
    el.output.classList.toggle("low", bad);
    el.tileK.classList.toggle("low", low.k);
    el.tileP.classList.toggle("low", low.ph);
    el.bak.dataset.state = bad ? "bad" : "ok";
    el.pill.className = "pill " + (bad ? "bad" : "ok");
    el.pill.querySelector("i").textContent = bad ? "!" : "✓";
    el.pill.querySelector("span").textContent = bad ? "Kualitas Larutan Menurun" : "Kualitas Larutan Baik";

    var canFix = bad && state.phase !== "repair";
    el.fix.hidden = !canFix;
    el.doneStatic.hidden = canFix;
    el.slider.disabled = state.phase === "repair";

    if (!bad) {
      if (state.phase === "alert") { state.phase = "monitor"; closeSheets(); }
      state.dismissed = false;
    } else if (state.phase === "monitor" && !state.dismissed) {
      state.phase = "alert";
      openSheet("alert");
      announce("Kualitas Bak 3 menurun. Tekan Mulai Perbaiki Larutan.");
    }
  }

  function dose() {
    var r = readings();
    var soda = Math.max(1, Math.round(26 * (PH_START - r.ph) / 1.3));
    var dyes = DYES.map(function (d) {
      return [d[0], Math.max(1, Math.round(d[1] * (1 - r.k / 100) * BATH_L / RECIPE_L))];
    });
    return { soda: soda, dyes: dyes, r: r };
  }

  function buildSteps() {
    var low = issue(readings());
    var steps = ["air"];
    if (low.ph) steps.push("ph");
    if (low.k) steps.push("kepekatan");
    return steps;
  }

  var TITLES = {
    air: "Penyesuaian Volume Air Larutan",
    ph: "Penyesuaian pH Air Larutan",
    kepekatan: "Penyesuaian Kepekatan Warna Larutan"
  };

  function renderStep() {
    var kind = state.steps[state.step];
    var d = dose();
    var last = state.step === state.steps.length - 1;
    el.progress.textContent = "Tahap " + (state.step + 1) + " dari " + state.steps.length;
    el.repairTitle.textContent = TITLES[kind];
    el.next.textContent = last ? "Selesai" : "Selanjutnya";
    var html = "";

    if (kind === "air") {
      html += "<p>Tambahkan air ke dalam wadah untuk menyesuaikan volume dasar larutan.</p>" +
        '<div class="water"><b>Tambahkan Air</b><span class="val" id="simWater">' + state.water + '</span><span>L</span>' +
        '<span class="stepper"><button type="button" id="simMinus" aria-label="Kurangi air">−</button>' +
        '<button type="button" id="simPlus" aria-label="Tambah air">+</button></span></div>';
    } else if (kind === "ph") {
      html += '<div class="callout">Tambahkan kostik sebanyak ' + d.soda + " gr</div>" +
        '<dl class="rows"><div><dt>Target level pH</dt><dd>' + fmtPh(PH_START) + "</dd></div>" +
        '<div><dt>Level pH sekarang</dt><dd class="red">' + fmtPh(d.r.ph) + "</dd></div></dl>" +
        '<p class="note">Tunggu beberapa saat agar larutan air mencapai target pH semula.</p>';
    } else {
      html += d.dyes.map(function (x) { return '<div class="callout">Tambahkan ' + x[0] + " sebanyak " + x[1] + " gr</div>"; }).join("") +
        '<dl class="rows"><div><dt>Target kepekatan warna</dt><dd>100%</dd></div>' +
        '<div><dt>Kepekatan sekarang</dt><dd class="red">' + Math.round(d.r.k) + "%</dd></div></dl>" +
        '<p class="note">Tunggu beberapa saat agar larutan mencapai target kepekatan warna semula.</p>';
    }
    el.repairBody.innerHTML = html;
    el.next.disabled = kind === "air" && state.water < 1;

    if (kind === "air") {
      $("simPlus").addEventListener("click", function () { state.water = Math.min(9, state.water + 1); renderStep(); $("simPlus").focus({ preventScroll: true }); });
      $("simMinus").addEventListener("click", function () { state.water = Math.max(0, state.water - 1); renderStep(); $("simMinus").focus({ preventScroll: true }); });
    }
  }

  function startRepair() {
    state.phase = "repair";
    state.steps = buildSteps();
    state.step = 0;
    state.water = 0;
    renderStep();
    openSheet("repair");
    render();
  }

  function finish() {
    state.drop = 0;
    state.phase = "monitor";
    state.dismissed = false;
    el.slider.value = 0;
    lastFocus = el.slider;
    render();
    closeSheets();
    el.toast.hidden = false;
    announce("Bak kembali ke resep acuan.");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { el.toast.hidden = true; }, 3200);
  }

  function resetAll() {
    clearTimeout(toastTimer);
    el.toast.hidden = true;
    state.drop = 0;
    state.phase = "monitor";
    state.dismissed = false;
    el.slider.value = 0;
    closeSheets();
    render();
  }

  el.slider.addEventListener("input", function () {
    state.drop = parseInt(el.slider.value, 10) || 0;
    render();
  });
  el.reset.addEventListener("click", resetAll);
  el.start.addEventListener("click", startRepair);
  el.fix.addEventListener("click", startRepair);
  el.alertClose.addEventListener("click", function () {
    state.dismissed = true;
    state.phase = "monitor";
    render();
    closeSheets();
  });
  el.repairClose.addEventListener("click", function () {
    state.dismissed = true;
    state.phase = "monitor";
    render();
    closeSheets();
  });
  el.next.addEventListener("click", function () {
    if (state.step < state.steps.length - 1) {
      state.step += 1;
      renderStep();
      (el.next.disabled ? $("simPlus") : el.next).focus({ preventScroll: true });
    } else {
      finish();
    }
  });

  document.querySelectorAll("[data-preset]").forEach(function (b) {
    b.addEventListener("click", function () {
      if (state.phase === "repair") return;
      state.drop = parseInt(b.getAttribute("data-preset"), 10);
      state.dismissed = false;
      state.phase = "monitor";
      el.slider.value = state.drop;
      render();
    });
  });

  document.addEventListener("keydown", function (e) {
    if (el.scrim.hidden) return;
    if (e.key === "Escape") {
      state.dismissed = true;
      state.phase = "monitor";
      render();
      closeSheets();
      return;
    }
    if (e.key !== "Tab") return;
    var sheet = el.alert.hidden ? el.repair : el.alert;
    var items = sheet.querySelectorAll("button:not([disabled])");
    if (!items.length) return;
    var first = items[0];
    var last = items[items.length - 1];
    if (e.shiftKey && document.activeElement === first) { last.focus(); e.preventDefault(); }
    else if (!e.shiftKey && document.activeElement === last) { first.focus(); e.preventDefault(); }
  });

  // Device frame: iPhone or iPad.
  var buttons = document.querySelectorAll("[data-device]");
  buttons.forEach(function (b) {
    b.addEventListener("click", function () {
      var kind = b.getAttribute("data-device");
      device.className = "device " + kind;
      buttons.forEach(function (o) { o.setAttribute("aria-pressed", String(o === b)); });
    });
  });

  // Mark the nav link of the section in view.
  if ("IntersectionObserver" in window) {
    var links = {};
    document.querySelectorAll(".nav a[href^='#']").forEach(function (a) { links[a.getAttribute("href").slice(1)] = a; });
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        var a = links[en.target.id];
        if (!a) return;
        if (en.isIntersecting) {
          Object.keys(links).forEach(function (k) { links[k].removeAttribute("aria-current"); });
          a.setAttribute("aria-current", "true");
        } else {
          a.removeAttribute("aria-current");
        }
      });
    }, { rootMargin: "-35% 0px -55% 0px" });
    Object.keys(links).forEach(function (id) { var sec = document.getElementById(id); if (sec) io.observe(sec); });
  }

  render();
})();
