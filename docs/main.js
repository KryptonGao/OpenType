(() => {
  const header = document.getElementById("siteHeader");
  const heroWindow = document.getElementById("heroWindowWrap");
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function onScroll() {
    const y = window.scrollY;
    header.classList.toggle("scrolled", y > 36);
    if (!reducedMotion && heroWindow && y < 720) {
      const shift = Math.max(0, Math.min(y * 0.04, 24));
      heroWindow.style.transform = `translate3d(0, ${-shift}px, 0)`;
    }
  }

  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // Directional & staggered scroll reveal
  function setupReveal(selector, direction = "up", staggerMs = 0) {
    document.querySelectorAll(selector).forEach((el, idx) => {
      el.setAttribute("data-reveal", direction);
      if (staggerMs) {
        el.style.transitionDelay = `${idx * staggerMs}ms`;
      }
    });
  }

  setupReveal(".section-header, .carousel-head, .closing-cta", "up", 0);
  setupReveal(".mode-card", "up", 90);
  setupReveal(".surface-card", "up", 80);
  setupReveal(".quote-card", "up", 70);

  document.querySelectorAll(".showcase-row").forEach((row) => {
    const reversed = row.classList.contains("is-reversed");
    const copy = row.querySelector(".showcase-copy");
    const media = row.querySelector(".showcase-media");
    if (copy) copy.setAttribute("data-reveal", reversed ? "right" : "left");
    if (media) {
      media.setAttribute("data-reveal", reversed ? "left" : "right");
      media.style.transitionDelay = "90ms";
    }
  });

  if (reducedMotion || !("IntersectionObserver" in window)) {
    document.querySelectorAll("[data-reveal]").forEach((el) => el.classList.add("is-visible"));
  } else {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && (entry.intersectionRatio >= 0.1 || entry.intersectionRect.height >= 80)) {
            entry.target.classList.add("is-visible");
          } else if (!entry.isIntersecting) {
            entry.target.classList.remove("is-visible");
          }
        });
      },
      { threshold: [0, 0.1], rootMargin: "0px 0px -32px 0px" }
    );

    document.querySelectorAll("[data-reveal]").forEach((el) => observer.observe(el));
  }

  // Horizontal carousel controls
  const track = document.getElementById("carouselTrack");
  const prevBtn = document.getElementById("prevBtn");
  const nextBtn = document.getElementById("nextBtn");

  if (track && prevBtn && nextBtn) {
    prevBtn.addEventListener("click", () => {
      track.scrollBy({ left: -360, behavior: "smooth" });
    });
    nextBtn.addEventListener("click", () => {
      track.scrollBy({ left: 360, behavior: "smooth" });
    });
  }

  // Screenshot slot detection & lightbox
  const lightbox = document.getElementById("lightbox");
  const lightboxImg = document.getElementById("lightboxImg");
  const lightboxClose = document.getElementById("lightboxClose");

  function openLightbox(src, alt) {
    if (!lightbox || !lightboxImg) return;
    lightboxImg.src = src;
    lightboxImg.alt = alt || "";
    lightbox.classList.add("is-open");
    lightbox.setAttribute("aria-hidden", "false");
  }

  function closeLightbox() {
    if (!lightbox) return;
    lightbox.classList.remove("is-open");
    lightbox.setAttribute("aria-hidden", "true");
  }

  if (lightbox) {
    lightbox.addEventListener("click", (e) => {
      if (e.target === lightbox || e.target === lightboxClose) {
        closeLightbox();
      }
    });
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && lightbox.classList.contains("is-open")) {
        closeLightbox();
      }
    });
  }

  document.querySelectorAll("[data-slot]").forEach((slot) => {
    const img = slot.querySelector("img.slot-img");
    if (!img) return;

    const markLoaded = () => {
      if (img.naturalWidth > 0) {
        slot.classList.add("has-image");
      }
    };

    const markMissing = () => {
      slot.classList.remove("has-image");
    };

    img.addEventListener("load", markLoaded);
    img.addEventListener("error", markMissing);

    if (img.complete) {
      if (img.naturalWidth > 0) markLoaded();
      else markMissing();
    }

    slot.addEventListener("click", () => {
      if (slot.classList.contains("has-image")) {
        openLightbox(img.src, img.alt);
      }
    });
  });

  // Language switchers (header & footer custom dropdowns)
  const langDropdowns = [
    {
      container: document.getElementById("langSwitcher"),
      trigger: document.getElementById("langBtn")
    },
    {
      container: document.getElementById("footerLangSwitcher"),
      trigger: document.getElementById("footerLangBtn")
    }
  ].filter((item) => item.container && item.trigger);

  function setDropdownOpen(item, open) {
    item.container.classList.toggle("is-open", open);
    item.trigger.setAttribute("aria-expanded", open ? "true" : "false");
  }

  function closeAllLangDropdowns() {
    langDropdowns.forEach((item) => setDropdownOpen(item, false));
  }

  langDropdowns.forEach((item) => {
    item.trigger.addEventListener("click", (e) => {
      e.stopPropagation();
      const willOpen = !item.container.classList.contains("is-open");
      closeAllLangDropdowns();
      setDropdownOpen(item, willOpen);
    });
  });

  if (langDropdowns.length) {
    document.addEventListener("click", (e) => {
      const clickedInside = langDropdowns.some((item) => item.container.contains(e.target));
      if (!clickedInside) {
        closeAllLangDropdowns();
      }
    });

    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        const opened = langDropdowns.find((item) => item.container.classList.contains("is-open"));
        if (opened) {
          closeAllLangDropdowns();
          opened.trigger.focus();
        }
      }
    });
  }

  document.querySelectorAll("[data-lang-option]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const targetLang = btn.getAttribute("data-lang-option");
      if (targetLang && window.OpenTypeI18n) {
        window.OpenTypeI18n.setLanguage(targetLang);
      }
      closeAllLangDropdowns();
    });
  });

  // Gatekeeper command copy
  const copyCmdBtn = document.getElementById("copyCmdBtn");
  const gatekeeperCmd = document.getElementById("gatekeeperCmd");
  let copyTimer = null;
  if (copyCmdBtn && gatekeeperCmd && navigator.clipboard) {
    copyCmdBtn.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(gatekeeperCmd.textContent.trim());
        const i18n = window.OpenTypeI18n;
        copyCmdBtn.textContent = i18n ? i18n.getString("copiedBtn") : "Copied";
        if (copyTimer) clearTimeout(copyTimer);
        copyTimer = setTimeout(() => {
          copyCmdBtn.textContent = i18n ? i18n.getString("copyBtn") : "Copy";
        }, 1600);
      } catch {
        // Ignore clipboard errors when opened over restricted contexts
      }
    });
  }
})();
