function toggleVisibility(id) {
	var obj=document.getElementById(id);
	if (obj.style.display=='none') {
		obj.style.display='';
	}
	else {
		obj.style.display='none';
	}
}
