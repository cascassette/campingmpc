/* script.js
 * part of WebMPC v0.2
 * this will have EVERYTHING javascript in time :)
 */

// init {{{
var appName = 'CampingMPC v0.3 (full ajax)';
var tbar_width_px = 400;
var tbar_t_elapsed, tbar_t_total=200;
var songpos;
var intah=0;
var playtime_intah=0;
var full_ui=true;
var p;
var ppbutton;
var repeat=false, random=false;
// }}}

// base {{{
/* plans; {{{
 * update errthing
 *  update playtime every sec
 * sync from mpd
 *  sync playtime 5 seconds after done loading page
 *  sync state/current/playtime track every 30 secs
 *  sync playlist every 1 min
 * }}} */
/* init_info_framework {{{ */
init_info_framework = function(t_elapsed, t_total, pos, playing, repeating, randoming) {
	songpos = pos;
	init_timebar(t_elapsed, t_total, playing);
	p = playing;
	repeat = repeating;
	random = randoming;
	$('repeat').children[0].checked = repeat;
	$('random').children[0].checked = random;
	if (p) {
		intah = setInterval("inc_time();", 1000);
		$('b_play').style.display='none';
		setTimeout("updateplaytime()", 5000);
	} else {
		$('b_pause').style.display='none';
	}
	setTimeout("multiple([$('headerbar'), $('controlbar')], appear)", 500);
	setTimeout("blindDown('subframe')", 1000);
	setTimeout("setDisplayForElement('inline', $$('ul.tab')[0]);", 1200);
}
/* }}} */
// }}}

// xhr actions {{{
/* play/pause/stop {{{ */
play = function() { playpause(); }
pause = function() { playpause(); }
playpause = function() {
	req = doXHR('/playpause');
	req.addCallback(function(result) {
		if ( result.readyState==4 &&  result.responseText == "OK" ) {
			updatestatus();
		}
	});
}
stop = function() {
	req = doXHR('/stop');
	req.addCallback(function(result) {
		if ( result.readyState==4 && result.responseText == "OK" ) {
			p = false;
			clearInterval(intah);
			$$('h1')[0].innerHTML='';
			$$('h2')[0].innerHTML='(stopped)';
			$('b_pause').style.display='none';
			$('b_play').style.display='inline';
			$('progressbartextlayer').innerHTML='';
		}
	});
}
/* }}} */
/* prev/next {{{ */
prev = function() {
	req = doXHR('/prev');
	req.addCallback(function(result) {
		if ( result.readyState==4 && result.responseText == "OK" ) {
			updatesong();
		}
	});
}
next = function() {
	req = doXHR('/next');
	req.addCallback(function(result) {
		if ( result.readyState==4 && result.responseText == "OK" ) {
			updatesong();
		}
	});
}
/* }}} */
/* playno: jump to in playlist {{{ */
playno = function(i) {
	req = doXHR('/playno/'+i);
	req.addCallback(function(result) {
		log(result);
		if ( result.readyState==4 && result.responseText == "OK" ) {
			updatesong();
		}
	});
}
/* }}} */
/* seek: jump to in song {{{ */
seek = function(new_time) {
	req = doXHR('/seek/'+songpos+'/'+new_time);
	req.addCallback( function(result) {
		if ( result.readyState == 4 && result.responseText == "OK" ) {
			tbar_t_elapsed=new_time;
			set_tb_time();
		}
	});
}
/* }}} */
/* togglempc: toggle repeat or random {{{ */
togglempc = function(name) {
	req = doXHR('/toggle'+name);
	req.addCallback( function(result) {
		if ( result.readyState == 4 && (result.responseText == "true" || result.responseText == "false" ) ) {
			repeat = eval(result.responseText);
		}
	} );
}
/* }}} */
// }}}

// toggle repeat & random (event handlers) {{{
/* toggledivclick, toggleclick (div, checkbox) {{{ */
toggledivclick = function( divName, event ) {
	divName.children[0].checked = !divName.children[0].checked;
	toggleclick( divName.children[0], event );
}
toggleclick = function( boxName, event ){
	funcname = boxName.parentNode.id;
	togglempc(funcname);
	// NOTE to be replaced by sth updatestatus
	if (boxName.checked) { addElementClass( boxName.parentNode, 'checked'); }
	else { removeElementClass( boxName.parentNode, 'checked'); }
	if (eval(funcname)) { addElementClass( boxName.parentNode, 'checked'); }
	else { removeElementClass( boxName.parentNode, 'checked'); }
}
/* }}} */
// }}}

// update functions {{{
/* updatesong {{{ */
updatesong = function() {
	req = doXHR('/currentsong');
	req.addCallback(function(result) {
		if ( result.readyState==4 ) {
			s = eval("("+result.responseText+")");
			// set title, artist, album, etc.
			title = s.title || s.file.substring(s.file.lastIndexOf('/')+1);
			$$('h1')[0].innerHTML = title
			$$('h2')[0].innerHTML = "by <i>" + (s.artist || "Unknown Artist")
				+ "</i> from <i>" + (s.album || "Unknown Album") + "</i>"
			if (s.track) {
				$$('h2')[0].innerHTML += " (<span>" + s.track + "</span>)"
			}
			document.title = (s.artist ? s.artist + " - " : "");
			document.title += title;
			document.title += (s.album ? "(" + s.album + ")" : "");
			document.title += " " + appName;
			updatestatus();
		}
	});
}
// }}}
/* updatestatus {{{ */
updatestatus = function() {
	req = doXHR('/status');
	req.addCallback(function(result) {
		if ( result.readyState==4 ) {
			r = eval("("+result.responseText+")");
			// update time elapsed & total
			[tbar_t_elapsed, tbar_t_total] = r.time.split(':');
			set_tb_time();
			// update status
			p = r.state == 'play';
			if (p) {
				$('b_play').style.display='none';
				$('b_pause').style.display='inline';
				clearInterval(intah);
				intah = setInterval("inc_time();", 1000);
				if (tbar_t_total > 3600) {
					// sync playtime every ten minutes if tracklen > hour
					clearInterval(playtime_intah);
					playtime_intah = setInterval("updateplaytime()", 600000);
				}
			} else {
				$('b_pause').style.display='none';
				$('b_play').style.display='inline';
				clearInterval(intah);
			}
			// update toggle buttons
			if (r.repeat=='1') {
				addElementClass( 'repeat', 'checked' );
				$('repeat').children[0].checked = true;
			} else {
				removeElementClass( 'repeat', 'checked' );
				$('repeat').children[0].checked = false;
			}
			if (r.random=='1') {
				addElementClass( 'random', 'checked' );
				$('random').children[0].checked = true;
			} else {
				removeElementClass( 'random', 'checked' );
				$('random').children[0].checked = false;
			}
			// update playlist entry highlight
			songpos = r.songid;
			withDocument( $('subframe').contentDocument, function() {
				removeElementClass($$('.currentsong')[0], 'currentsong');
				addElementClass('pl'+songpos, 'currentsong');
			});
		}
	});
}
// }}}
/* updateplaytime {{{ */
updateplaytime = function() {
	req = doXHR('/playtime');
	req.addCallback(function(result) {
		if ( result.readyState==4 ) {
			[tbar_t_elapsed, tbar_t_total] = result.responseText.split(':');
			set_tb_time();
		}
	});
}
// }}}
/* updateplaylist {{{ */
updateplaylist = function() {
	req = doXHR('/playlistding');
	req.addCallback(function(result) {
		if ( result.readyState==4 ) {
			r = eval('('+result.responseText+')');
			tbl = "<tr class='header'><th>&nbsp;</th><th>Artist</th><th>Track</th><th>Length</th></tr>";
			forEach(r, function(item) {
				tbl += "<tr id='tr"+item.pos+"' onclick='parent.playno("+item.pos+")'>";
				tbl += "<td><img src='/img/musicfile.png'></td>";
				tbl += "<td>"+item.artist+"</td>";
				tbl += "<td>"+item.title+"</td>";
				tbl += "<td class='tracklen'>"+secstotimestr(item.time)+"</td>";
				tbl += "</tr>";
			});
			withDocument( $('subframe').contentDocument, function() {
				$$('table.playlist')[0].innerHTML = tbl;
			});
		}
	});
}
// }}}
// }}}

// timebar {{{
/* init_timebar, timers {{{ */
init_timebar = function(t_elapsed, t_total, playing) {
	tbar_t_elapsed = t_elapsed;
	tbar_t_total = t_total;
	set_tb_time();
}
inc_time = function() {		// used to increase tbar_t_elapsed every second
	if (tbar_t_elapsed < tbar_t_total) {
		tbar_t_elapsed++;
		set_tb_time();
	} else {
		clearInterval(intah);
		updatesong();
	}
}
set_tb_time = function() {
	$$("div#progressbartextlayer")[0].innerHTML=secstotimestr(tbar_t_elapsed) + " / " + secstotimestr(tbar_t_total);
	$$("div#progressbar")[0].style.width = (tbar_t_elapsed/tbar_t_total)*(tbar_width_px-8);		// 8 is for indicator width+border
}
/* }}} */
/* do_seek (event handler) {{{ */
do_seek = function(event) {
	pos_x = event.offsetX?event.offsetX:event.pageX-document.getElementById('progressbarcontainer').offsetLeft;
	pos_x -= 6;
	pos_x = ( pos_x < 0? 0 : pos_x )
	newtime=Math.floor((pos_x/tbar_width_px)*tbar_t_total);
	// do ajax-ish call to seek
	seek(newtime);
}
/* }}} */
// }}}

// formatting {{{
/* secstotimestr {{{ */
secstotimestr = function(secs) {
	sec = secs % 60;
	min = (secs - sec) / 60;
	min = Math.floor( min );
	if ( min >= 60 )
	{
		mint = min % 60;
		hour = ( min - mint ) / 60;
		mint = Math.floor( mint );
		sec = numberFormatter("00")(sec);
		mint = numberFormatter("00")(mint);
		return (hour + ":" + mint + ":" + sec);
	}
	else
	{
		sec = numberFormatter("00")(sec);
		return (min + ":" + sec);
	}
}
/* }}} */
// }}}

// effects {{{
/* switch_default_minimal_style {{{ */
switch_default_minimal_style = function() {
	hb=$('headerbar');
	cb=$('controlbar');
	full_ui = !full_ui;
	if (!full_ui) {
		hideElement($$('ul.tab')[0]);
		hideElement($('subframe'));
		hideElement($('toggles'));
		hb.style.padding='10px';
		hb.style.backgroundColor='black';
		setOpacity(hb, 0);
		cb.style.padding='20px';
		cb.style.backgroundColor='black';
		setOpacity(cb, 0);
		$('sw').innerHTML='switch to full';
		realign();
		multiple([hb, cb], appear, {from: 0.0, to: 0.7});
	} else {
		setOpacity(hb, 0.01);
		setOpacity(cb, 0.01);
		hb.style.marginTop='0';
		hb.style.padding='0';
		hb.style.background='none';
		cb.style.marginTop='0';
		cb.style.padding='0';
		cb.style.background='none';
		$('sw').innerHTML='switch to mini';
		setTimeout('multiple([hb, cb], appear)', 500);
		setTimeout("blindDown('subframe')", 1000);
		setTimeout("setDisplayForElement('inline', $$('ul.tab')[0]);", 1200);
		setTimeout("appear($('toggles'))", 2000);
	}
}
/* }}} */
/* realign {{{ */
realign = function() {
	if (!full_ui) {
		hb=$('headerbar');
		cb=$('controlbar');
		hb.style.marginTop=(window.innerHeight/4-hb.clientHeight/2);
		cb.style.marginTop=(window.innerHeight/2-cb.clientHeight/2-hb.clientHeight/2);
	}
}
/* }}} */
// }}}
