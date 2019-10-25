$(document).ready(function() {
  $('input[type="checkbox"]').each(function() {
    $(this).wrap("<label for='" + $(this).attr("name") + "'/>");
    $(this).attr("id", $(this).attr("name"));
    $("[for='" + $(this).attr("name") + "']").append("<span />");
  });

  M.AutoInit();

  var elem = document.querySelector(".collapsible.expandable");
  var instance = M.Collapsible.init(elem, {
    accordion: false
  });

  $('input[type="submit"]').addClass("btn");

  $("input:not(.sidenav input)").css({ color: "white" });
});
