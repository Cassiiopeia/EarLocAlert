/* 소개 사이트 연출 (#365): 제목 단어 등장 · 폰 기울기 · 도착 연출 · 셔틀 노선 · 사용법 화면 교체 · 등장 · 벤토
   요소가 없는 페이지에서는 해당 연출을 건너뜀. 움직임 줄이기 설정이면 정지 상태로 둠 */
(function () {
  "use strict";
  var shouldReduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  document.addEventListener("DOMContentLoaded", function () {
    setupWordReveal();
    setupLanguageMenus();
    setupRevealOnScroll();
    setupStorySteps();
    if (shouldReduceMotion) { return; }
    setupHeroTilt();
    setupArriveScene();
    setupShuttleRoute();
    setupFeatureTicks();
  });

  // 제목 단어별 흐림 > 선명 (공백 단위, 일·중은 공백이 적어 덩어리째)
  function setupWordReveal() {
    var title = document.querySelector("[data-word-reveal]");
    if (!title || shouldReduceMotion) { return; }
    var wordIndex = 0;
    Array.prototype.slice.call(title.childNodes).forEach(function (node) {
      var fragment = document.createDocumentFragment();
      var isAccent = node.nodeType === 1;
      node.textContent.split(/(\s+)/).forEach(function (part) {
        if (!part.trim()) { fragment.appendChild(document.createTextNode(part)); return; }
        var word = document.createElement(isAccent ? "em" : "span");
        word.className = "word";
        word.textContent = part;
        word.style.animationDelay = (wordIndex++ * 80) + "ms";
        fragment.appendChild(word);
      });
      title.replaceChild(fragment, node);
    });
  }

  // 언어 메뉴: 바깥을 누르거나 Esc 면 닫힘
  function setupLanguageMenus() {
    var menus = document.querySelectorAll(".lang-menu");
    document.addEventListener("click", function (event) {
      menus.forEach(function (menu) { if (!menu.contains(event.target)) { menu.removeAttribute("open"); } });
    });
    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape") { menus.forEach(function (menu) { menu.removeAttribute("open"); }); }
    });
  }

  // 등장 연출: 화면에 들어오면 한 번 (같은 묶음 안에서 순서대로 지연)
  function setupRevealOnScroll() {
    var elements = document.querySelectorAll(".reveal, .tile");
    if (!("IntersectionObserver" in window) || shouldReduceMotion) {
      elements.forEach(function (element) { element.classList.add("is-visible"); });
      return;
    }
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry, index) {
        if (!entry.isIntersecting) { return; }
        entry.target.style.transitionDelay = (index * 80) + "ms";
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    }, { threshold: 0.15 });
    elements.forEach(function (element) { observer.observe(element); });
  }

  // 사용법: 화면 가운데 온 단계 > 고정 폰 화면 교체
  function setupStorySteps() {
    var steps = document.querySelectorAll("[data-step]");
    var shots = document.querySelectorAll(".story-phone [data-shot]");
    if (!steps.length || !("IntersectionObserver" in window)) { return; }
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) { return; }
        var activeShot = entry.target.getAttribute("data-step");
        steps.forEach(function (step) { step.classList.toggle("is-active", step === entry.target); });
        shots.forEach(function (shot) { shot.classList.toggle("is-active", shot.getAttribute("data-shot") === activeShot); });
      });
    }, { rootMargin: "-45% 0px -45% 0px" });
    steps.forEach(function (step) { observer.observe(step); });
  }

  // 첫 화면 폰: 스크롤 0~450px 동안 기울기 28도 > 0도
  function setupHeroTilt() {
    var tilt = document.querySelector("[data-tilt]");
    if (!tilt) { return; }
    var tiltScrollPixels = 450, isFrameRequested = false;
    function applyTilt() {
      var progress = Math.min(window.scrollY / tiltScrollPixels, 1);
      tilt.style.transform = "rotateX(" + (28 - progress * 28) + "deg) scale(" + (0.92 + progress * 0.08) + ")";
      isFrameRequested = false;
    }
    window.addEventListener("scroll", function () {
      if (!isFrameRequested) { isFrameRequested = true; window.requestAnimationFrame(applyTilt); }
    }, { passive: true });
    applyTilt();
  }

  // 도착 연출: 보이면 시작 > 버스 2.2초 이동 > 반경 진입 시 화면 켜짐·진동 2.6초 > 반복 (안 보이면 멈춤)
  function setupArriveScene() {
    var scene = document.querySelector("[data-arrive]");
    if (!scene) { return; }
    var route = scene.querySelector("[data-route]"), bus = scene.querySelector("[data-bus]");
    var zoneFill = scene.querySelector("[data-zone-fill]"), zoneEdge = scene.querySelector("[data-zone-edge]");
    var phone = scene.querySelector(".phone"), screenOff = scene.querySelector("[data-screen-off]");
    var vibes = scene.querySelectorAll("[data-vibe]"), notification = scene.querySelector("[data-notification]");
    var status = scene.querySelector("[data-status]"), statusText = status.querySelector("span");
    var zoneX = Number(scene.dataset.zoneX), zoneY = Number(scene.dataset.zoneY), zoneRadius = Number(scene.dataset.zoneRadius);
    var routeLength = route.getTotalLength();
    var rideMilliseconds = 2200, alertMilliseconds = 2600, pauseMilliseconds = 900;
    var rideStart = null, hasArrived = false, isVisible = false;

    new IntersectionObserver(function (entries) {
      isVisible = entries[0].isIntersecting;
      if (isVisible && rideStart === null) { rideStart = performance.now(); requestAnimationFrame(tick); }
    }, { threshold: 0.35 }).observe(scene);

    function tick(now) {
      var elapsed = now - rideStart;
      var progress = Math.min(elapsed / rideMilliseconds, 1);
      var eased = progress < 0.5 ? 2 * progress * progress : 1 - Math.pow(-2 * progress + 2, 2) / 2;
      var point = route.getPointAtLength(eased * routeLength);
      bus.setAttribute("transform", "translate(" + point.x + " " + point.y + ")");
      var isInsideZone = Math.hypot(point.x - zoneX, point.y - zoneY) < zoneRadius;
      if (isInsideZone && !hasArrived) { startAlert(); }
      if (hasArrived && elapsed > rideMilliseconds + alertMilliseconds) { stopAlert(); }
      zoneEdge.setAttribute("r", zoneRadius + Math.sin(now / 350) * 5);
      if (elapsed > rideMilliseconds + alertMilliseconds + pauseMilliseconds) {
        if (!isVisible) { rideStart = null; return; }
        rideStart = now;
      }
      requestAnimationFrame(tick);
    }
    function startAlert() {
      hasArrived = true;
      zoneFill.setAttribute("r", zoneRadius * 1.6);
      screenOff.style.opacity = 0;
      phone.classList.add("is-buzzing");
      vibes.forEach(function (vibe) { vibe.classList.add("is-on"); });
      notification.classList.add("is-shown");
      status.classList.add("is-arrived");
      statusText.textContent = scene.dataset.statusArrived;
    }
    function stopAlert() {
      hasArrived = false;
      zoneFill.setAttribute("r", zoneRadius);
      screenOff.style.opacity = 1;
      phone.classList.remove("is-buzzing");
      vibes.forEach(function (vibe) { vibe.classList.remove("is-on"); });
      notification.classList.remove("is-shown");
      status.classList.remove("is-arrived");
      statusText.textContent = scene.dataset.statusMoving;
    }
  }

  // 셔틀 노선: 정류장 0.75초마다 통과 > 마지막(내릴 곳)에서 진동 알림 1.8초 > 처음부터
  function setupShuttleRoute() {
    var card = document.querySelector("[data-shuttle]");
    if (!card) { return; }
    var stops = card.querySelectorAll("[data-stop]"), fill = card.querySelector("[data-route-fill]"), alert = card.querySelector("[data-route-alert]");
    var stopIndex = 0, isWaitingAtTarget = false, hasStarted = false;
    function advance() {
      if (isWaitingAtTarget) { return; }
      stops.forEach(function (stop, index) { stop.classList.toggle("is-passed", index < stopIndex); });
      var reachedStop = stops[stopIndex];
      fill.style.height = (reachedStop.offsetTop + reachedStop.offsetHeight / 2 - 8) + "px";
      if (stopIndex === stops.length - 1) {
        isWaitingAtTarget = true;
        alert.classList.add("is-shown");
        setTimeout(function () { stopIndex = 0; isWaitingAtTarget = false; alert.classList.remove("is-shown"); }, 1800);
        return;
      }
      stopIndex += 1;
    }
    new IntersectionObserver(function (entries) {
      if (entries[0].isIntersecting && !hasStarted) { hasStarted = true; advance(); setInterval(advance, 750); }
    }, { threshold: 0.4 }).observe(card);
  }

  // 벤토 작은 연출: 반경 라벨 순환, 월~금 차례로 켜짐
  function setupFeatureTicks() {
    var radiusLabel = document.querySelector("[data-radius-steps]");
    if (radiusLabel) {
      var radiusSteps = radiusLabel.getAttribute("data-radius-steps").split("|"), radiusIndex = 0;
      setInterval(function () { radiusIndex = (radiusIndex + 1) % radiusSteps.length; radiusLabel.textContent = radiusSteps[radiusIndex]; }, 600);
    }
    var weekdayChips = document.querySelectorAll("[data-weekdays] b"), weekdayTick = 0;
    var workdayCount = 5, weekdayCycleLength = 8;
    if (weekdayChips.length) {
      setInterval(function () {
        weekdayChips.forEach(function (chip, index) { chip.classList.toggle("is-on", index < workdayCount && index <= weekdayTick % weekdayCycleLength); });
        weekdayTick += 1;
      }, 450);
    }
  }
})();
