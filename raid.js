function getHTTPObject() {
  var xmlhttp;
  /*@cc_on
  @if (@_jscript_version >= 5)
    try {
      xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");
    } catch (e) {
      try {
        xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
      } catch (E) {
        xmlhttp = false;
      }
    }
  @else
  xmlhttp = false;
  @end @*/

  if (!xmlhttp && typeof XMLHttpRequest != 'undefined') {
    try {
      xmlhttp = new XMLHttpRequest();
    } catch (e) {
      xmlhttp = false;
    }
  }
  return xmlhttp;
}

var HTTP = getHTTPObject();
var modified = '_';

function claim(dataSource, target, wave,cmd){
	if(HTTP) {
		var url = dataSource + '&cmd='+cmd+'&target=' + target + '&wave=' + wave;
		//obj.innerHTML = "test";
		HTTP.open("GET", url,true);
		HTTP.onreadystatechange = function(){
			if (HTTP.readyState == 4 &&
					HTTP.status == 200) {
				updateClaims(dataSource,HTTP.responseXML,false);
				var obj = document.getElementById("targets");
				if (obj){
					var re = new RegExp("targetlist>(.*)</targetlist", "m");
					re.test(HTTP.responseText);
					obj.innerHTML = RegExp.$1;
				}
			}
		}
		HTTP.send(null);
	}
}

function listTargets(dataSource){
	var http = getHTTPObject();
	http.open("GET",dataSource+'&cmd=gettargets',true);
	http.onreadystatechange = function(){
		if (http.readyState == 4 &&
				http.status == 200) {
			var obj = document.getElementById("targets");
			if (obj)
				obj.innerHTML = http.responseText;
		}
	}
	http.send(null);
}

function update(dataSource){
	if(HTTP) {
		HTTP.open("GET",dataSource+"&cmd=update&from="+modified,true);
		HTTP.onreadystatechange = function(){
			if (HTTP.readyState == 4 &&
					HTTP.status == 200) {
				updateClaims(dataSource,HTTP.responseXML,true);
			}
		}
		HTTP.send(null);
	}
}

function updateClaims(dataSource,xmldoc,timestamp){
	targets = xmldoc.getElementsByTagName("target");
	for (var i = 0; i < targets.length; i++){
		var target = targets[i].attributes.getNamedItem("id").nodeValue;
		var obj = document.getElementById("claim"+target);
		if (!obj)
			continue;
		obj.innerHTML = '';
		var waves = targets[i].getElementsByTagName("wave");;
		for (var j = 0; j < waves.length; j++){
			var command = waves[j].firstChild.nextSibling;
			var claimers = command.nextSibling;
			var joinable = claimers.nextSibling;
			var wave = waves[j].attributes.getNamedItem("id").nodeValue;
			command = command.firstChild.nodeValue;
			if(claimers.firstChild){
				claimers = '('+claimers.firstChild.nodeValue+')';
			}else
				claimers = '';
			joinable = joinable.firstChild.nodeValue;

			if (command == 'none'){
				var s = document.createElement("b");
				s.appendChild(document.createTextNode("Claimed by "+claimers));
				obj.appendChild(s);
			}else{
				var b = document.createElement("input");
				b.type = 'button';
				b.setAttribute("class", command);
				b.value = command +' wave '+wave+' '+claimers;
				b.setAttribute("onClick", "claim('"+dataSource+"',"+target+","+wave+",'"+command+"')");
				/*b.onclick = function(){
					claim(dataSource,t,wave,command);
				}*/
				obj.appendChild(b);
			}
			if (command == 'unclaim'){
				var b = document.createElement("input");
				b.type = 'button';
				b.value = 'J';
				command = 'set&joinable=TRUE';
				if (joinable == 1){
					b.value = 'N';
					command = 'set&joinable=FALSE';
				}
				b.setAttribute("onClick", "claim('"+dataSource+"',"+target+","+wave+",'"+command+"')");
				obj.appendChild(b);
			}
		}
		obj = document.getElementById("coords"+target);
		var coords = targets[i].getElementsByTagName("coords");;
		if (obj)
			obj.innerHTML = coords[0].firstChild.nodeValue;
	}
	if (timestamp){
		timestamp = xmldoc.getElementsByTagName("timestamp");
		if (timestamp)
			modified = timestamp[0].firstChild.nodeValue;
	}
}
