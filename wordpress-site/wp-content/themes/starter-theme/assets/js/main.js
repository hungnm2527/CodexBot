(function() {
  const toggle = document.querySelector('.nav-toggle');
  const menu = document.querySelector('nav ul');
  if (toggle && menu) {
    toggle.addEventListener('click', () => {
      const expanded = toggle.getAttribute('aria-expanded') === 'true';
      toggle.setAttribute('aria-expanded', String(!expanded));
      menu.hidden = expanded;
    });
  }
})();

(function() {
  const slides = document.querySelectorAll('.slider-window .slide');
  const dots = document.querySelectorAll('.slider-dots button');
  if (!slides.length) return;

  let activeIndex = 0;

  const setActive = (index) => {
    slides[activeIndex].classList.remove('is-active');
    if (dots[activeIndex]) {
      dots[activeIndex].classList.remove('is-active');
    }
    activeIndex = index;
    slides[activeIndex].classList.add('is-active');
    if (dots[activeIndex]) {
      dots[activeIndex].classList.add('is-active');
    }
  };

  dots.forEach((dot) => {
    dot.addEventListener('click', () => {
      const target = Number(dot.dataset.targetSlide || 0);
      setActive(target);
    });
  });

  setInterval(() => {
    const nextIndex = (activeIndex + 1) % slides.length;
    setActive(nextIndex);
  }, 6000);
})();
