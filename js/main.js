// ============================================================
// E时代 站点导航与平滑滚动逻辑
// 关键：heoWeb 与滚动函数优先定义，不依赖外部库，
//       避免资源加载失败导致导航点击全部失效。
// ============================================================

// 平滑滚动 / 菜单控制对象（不依赖任何外部库）
var heoWeb = {
  // 显示菜单
  showMenu: function () {
    document.getElementById("body").classList.add("show-menu");
  },

  // 关闭菜单
  hideMenu: function () {
    document.getElementById("body").classList.remove("show-menu");
  },

  // 平滑跳转到指定 id 的区块
  scrollTo: function (id) {
    var target = document.getElementById(id);
    if (!target) return;
    var targetPosition = target.offsetTop - 60;
    var startPosition = window.pageYOffset;
    var distance = targetPosition - startPosition;
    var startTime = null;

    function ease(t, b, c, d) {
      t /= d / 2;
      if (t < 1) return (c / 2) * t * t + b;
      t--;
      return (-c / 2) * (t * (t - 2) - 1) + b;
    }

    function animation(currentTime) {
      if (startTime === null) startTime = currentTime;
      var timeElapsed = currentTime - startTime;
      var run = ease(timeElapsed, startPosition, distance, 600);
      window.scrollTo(0, run);
      if (timeElapsed < 600) requestAnimationFrame(animation);
    }

    requestAnimationFrame(animation);
  },
};

// 滚动回顶部（Logo 点击使用）
function scrollToTopWithAnimation() {
  var duration = 600;
  var startPosition = window.pageYOffset;
  var distance = -window.pageYOffset;
  var startTime = null;

  function easeInOutQuad(t, b, c, d) {
    t /= d / 2;
    if (t < 1) return (c / 2) * t * t + b;
    t--;
    return (-c / 2) * (t * (t - 2) - 1) + b;
  }

  function animation(currentTime) {
    if (!startTime) startTime = currentTime;
    var timeElapsed = currentTime - startTime;
    var scrollY = easeInOutQuad(timeElapsed, startPosition, distance, duration);
    window.scrollTo(0, scrollY);
    if (timeElapsed < duration) requestAnimationFrame(animation);
  }

  requestAnimationFrame(animation);
}

// 视差效果（simpleParallax 为本地脚本，缺失则跳过，不影响导航）
if (typeof simpleParallax !== "undefined") {
  try {
    var image = document.getElementsByClassName("banner-pic-img");
    new simpleParallax(image, {
      orientation: "up",
      scale: 1.2,
      delay: 2,
      transition: "cubic-bezier(0,0,0,1)",
      maxTransition: 50,
      overflow: true,
    });
  } catch (e) {}
}

// 菜单按钮（汉堡键）点击：切换菜单显隐
var menuButton = document.getElementById("nav-menu");
if (menuButton) {
  menuButton.addEventListener(
    "click",
    function () {
      if (document.getElementById("body").classList.contains("show-menu")) {
        heoWeb.hideMenu();
      } else {
        heoWeb.showMenu();
      }
    },
    false
  );
}

// 点击菜单项后收起菜单，并阻止菜单区域滚动穿透
var menuListEl = document.querySelector(".menu-list");
if (menuListEl) {
  menuListEl.addEventListener("click", function () {
    heoWeb.hideMenu();
  });
  menuListEl.addEventListener(
    "wheel",
    function (e) {
      e.preventDefault();
    },
    { passive: false }
  );
}
