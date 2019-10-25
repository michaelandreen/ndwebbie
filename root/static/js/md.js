$(document).ready(function() {
  $('input[type="checkbox"]').each(function() {
    $(this).wrap("<label for='" + $(this).attr("name") + "'/>");
    $(this).attr("id", $(this).attr("name"));
    $("[for='" + $(this).attr("name") + "']").append("<span />");
  });
  M.AutoInit();

  $('input[type="submit"]').addClass("btn");

  $("input:not(.sidenav input)").css({ color: "white" });
});
