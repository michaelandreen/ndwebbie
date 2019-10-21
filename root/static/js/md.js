const drawer = mdc.drawer.MDCDrawer.attachTo(
  document.querySelector(".mdc-drawer")
);

$(document).on("click", ".menu-nav-toggle", event => {
  drawer.open = !drawer.open;
});

adjustToWidth();

$(window).on("resize", () => {
  adjustToWidth();
});

function adjustToWidth() {
  let w = window.outerWidth;
  const drawer = mdc.drawer.MDCDrawer.attachTo(
    document.querySelector(".mdc-drawer")
  );
  if (w < 768) {
    drawer.open = false;
  } else {
    drawer.open = true;
  }
}
