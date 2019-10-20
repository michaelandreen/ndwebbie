$(document).ready(() => {
  const drawer = mdc.drawer.MDCDrawer.attachTo(
    document.querySelector(".mdc-drawer--modal")
  );

  $(document).on("click", ".menu-nav-toggle", event => {
    drawer.open = !drawer.open;
  });
});
