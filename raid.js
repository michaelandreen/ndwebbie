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

var modified = '_';

function claim(dataSource, target, wave,cmd){
	var HTTP = getHTTPObject();
	if(HTTP) {
		var url = dataSource + '&cmd='+cmd+'&target=' + target + '&wave=' + wave + '&rand='+ Math.random();
		//obj.innerHTML = "test";
		HTTP.open("GET", url,true);
		HTTP.onreadystatechange = function(){
			if (HTTP.readyState == 4 &&
					HTTP.status == 200) {
				updateClaims(dataSource,HTTP.responseXML,false);
				var obj = document.getElementById("targets");
				if (obj){
					clearObject(obj);
					var re = new RegExp("targetlist>((.|\\n)*)</targetlist");
					if(re.test(HTTP.responseText))
						obj.innerHTML = RegExp.$1;
				}
			}
		}
		HTTP.send(null);
	}
}

function clearObject(obj){
	while (obj.hasChildNodes()){
		obj.removeChild(obj.firstChild);
	}
}

function listTargets(dataSource){
	var http = getHTTPObject();
	http.open("GET",dataSource+'&cmd=gettargets' + '&rand='+ Math.random(),true);
	http.onreadystatechange = function(){
		if (http.readyState == 4 &&
				http.status == 200) {
			var obj = document.getElementById("targets");
			if (obj){
				clearObject(obj);
				var re = new RegExp("targetlist>((.|\\n)*)</targetlist");
				if(re.test(http.responseText))
					obj.innerHTML = RegExp.$1;
			}
		}
	}
	http.send(null);
}

function update(dataSource){
	var HTTP = getHTTPObject();
	if(HTTP) {
		HTTP.open("GET",dataSource+"&cmd=update&from="+modified + '&rand='+ Math.random(),true);
		HTTP.onreadystatechange = function(){
			if (HTTP.readyState == 4 &&
					HTTP.status == 200) {
				updateClaims(dataSource,HTTP.responseXML,true);
			}
		}
		HTTP.send(null);
	}
}

function updateClaims(dataSource,xmlthingy,timestamp){
	var targets = xmlthingy.getElementsByTagName("target");
	for (var i = 0; i < targets.length; i++){
		var target = targets[i].attributes.getNamedItem("id").nodeValue;
		var obj = document.getElementById("claim"+target);
		if (!obj)
			continue;
		//obj.innerHTML = '';
		clearObject(obj);
		var waves = targets[i].getElementsByTagName("wave");;
		for (var j = 0; j < waves.length; j++){
			var command = waves[j].getElementsByTagName("command")[0];
			var claimers = waves[j].getElementsByTagName("claimers")[0];
			var joinable = waves[j].getElementsByTagName("joinable")[0];
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
				b.setAttribute("onclick", "claim('"+dataSource+"',"+target+","+wave+",'"+command+"');");
				/*b.onclick = function(){
					claim(dataSource,t,wave,command);
				}*/
				obj.appendChild(b);
			}
			if (command == 'Unclaim'){
				var b = document.createElement("input");
				b.type = 'button';
				b.value = 'J';
				b.title = 'Make target joinable';
				command = 'set&joinable=TRUE';
				if (joinable == 1){
					b.value = 'N';
					b.title = 'Disable join';
					command = 'set&joinable=FALSE';
				}
				b.setAttribute("onclick", "claim('"+dataSource+"',"+target+","+wave+",'"+command+"');");
				obj.appendChild(b);
			}
			obj.innerHTML = obj.innerHTML; // IE doesn't understand unless you tell it twice
		}
		obj = document.getElementById("coords"+target);
		var coords = targets[i].getElementsByTagName("coords");;
		if (obj)
			obj.innerHTML = coords[0].firstChild.nodeValue;
	}
	if (timestamp){
		timestamp = xmlthingy.getElementsByTagName("timestamp");
		if (timestamp)
			modified = timestamp[0].firstChild.nodeValue;
	}
}
