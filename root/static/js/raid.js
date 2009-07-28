modified = "0001-01-01";

function parseUpdate(xml){
	if ($('timestamp',xml).text())
		modified = $('timestamp',xml).text();
	$('target',xml).each(function(i){
		var target = $(this).attr('id');
		var div = $('#claim'+target).empty();
		$('wave',$(this)).each(function(i){
			var wave = $(this).attr('id');
			var b = $('<input type="button">');
			var command = $(this).find('command').text();
			b.addClass(command);
			b.click(function(){
				claim(target,wave,command);
			});
			div.append(b);
			switch ($(this).find('command').text()){
				case 'taken':
					b.attr('disabled','disabled');
					b.val('Taken by '+$(this).find('claimers').text());
					if ($(this).find('claimers').text() == 'BLOCKED'){
						b.val($(this).find('claimers').text());
						b.addClass('blocked');
					}
					break;
				case 'claim':
					b.val('Claim wave '+wave);
					break;
				case 'join':
					b.val('Join wave '+wave
						+' ('+$(this).find('claimers').text()+')');
					break;
				case 'unclaim':
					b.val('Unclaim wave '+wave
						+' ('+$(this).find('claimers').text()+')');
					var j = $('<input type="button">');
					var joinable = $(this).find('joinable').text();
					j.click(function(){
						join(target,wave,joinable);
					});
					div.append(j);
					switch(joinable){
						case '0':
							j.val('J');
							j.attr('title','Make target joinable');
							break;
						case '1':
							j.val('N');
							j.attr('title','Disable joinable');
						break;
					}
					break;
			}
		});
	});
	if ($('targetlist',xml).text()){
		$('#targets').empty().html($('targetlist',xml).text());
	}
	if ($('noaccess',xml).text()){
		alert($('noaccess',xml).text());
	}
}


function listTargets(){
	$.get("/jsrpc/listTargets",{},parseUpdate);
}
