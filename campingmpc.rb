require 'librmpd'
require './mpclib.rb'
require './json.rb'

Camping.goes :CampingMPC

module CampingMPC::Controllers
	# Init
	@@c = MPD.new
	@@c.connect
	#@@c.password('ptfmwb')

	# Index controller
	class Index < R '/'
		def get
			@mpdstatus = @@c.status
			@s = @@c.current_song
			@playing = @mpdstatus['state']=="play"
			@artist = @s.fetch('artist', 'Unknown Artist')
			@album = @s.fetch('album', 'Unknown Album')
			@title = @s.fetch('title', @s['file'].split("/")[-1])
			@track = (@s.key? 'track') ? "(<span>#{@s['track']}</span>)" : ""
			@t_elapsed, @t_total = @mpdstatus['time'].split(":")
			@repeat = @@c.repeat?.to_s
			@random = @@c.random?.to_s
			render :index
		end
	end

	# Subframe controllers
	class Playlist < R '/playlist'
		def get
			@pos = @@c.current_song['pos']
			@plinfo = @@c.playlist
			#for s in @plinfo
				#for k in ['artist', 'title', 'album', 'genre', 'file'] do
					#s[k].force_encoding('utf-8') if s.key? k 
				#end
			#end
			render :playlist
		end
	end

	class Filetree < R '/filetree'
		def get
			@ftree = TreeList(@@c.files)
			render :filetree
		end
	end

	class Albumtree < R '/albumtree'
		def get
			alist = @@c.albums.sort
			@atree = {}
			for a in alist
				@atree.update({a => @@c.find('album', a)})
			end
			render :albumtree
		end
	end

	class Artisttree < R '/artisttree'
		def get
			r = "<ul class='tree'>"
			arlist = @@c.artists.sort
			for ar in arlist
				liclass = ( ar != arlist[-1] ? '' : ' class="last"' )
				r += "<li#{liclass}><img src='/img/artist16.png' /> #{( ar=='' ? 'Unknown Artist' : ar )} <a href='/addartist/#{ar}' target='_top'><img src='/img/add.png' /></a><ul>"
				tlist_artist = @@c.find('artist', ar)
				alist = tlist_artist.map{|t|t['album']}.uniq
				for a in alist
					liclass = ( a != alist[-1] ? '' : ' class="last"' )
					r += "<li#{liclass}><img src='/img/cd16.png' /> #{a} <a href='/addalbum/#{a}' target='_top'><img src='/img/add.png' /></a><ul>"
					tlist_album = tlist_artist.select{ |t| t['album'] == a }.sort_by{ |t| t.fetch('track', '0') }
					for t in tlist_album
						liclass = ( t != tlist_album[-1] ? '' : ' class="last"' )
						fn = t['file']
						ti = t.fetch('title', fn[0...fn.rindex('.')].split('/')[-1])
						r += "<li#{liclass}><img src='/img/musicfile.png' /> <a href='/addsong/\"#{t['file']}\"' target='_top'><img src='/img/add.png' /></a> #{ti}</li>"
					end
					r += "</ul></li>"
				end
				r += "</ul></li>"
			end
			r += "</ul>"
			@ularttree = r
			render :artisttree
		end
	end

	# MPC Actions
	class Play
		def get
			@@c.play
			render :ok
		end
	end

	class Pause
		def get
			@@c.pause = true
			render :ok
		end
	end

	class Playpause
		def get
			if @@c.playing?
				@@c.pause = true
			else
				@@c.play
			end
			render :ok
		end
	end

	class Stop
		def get
			@@c.stop
			render :ok
		end
	end

	class Prev
		def get
			@@c.previous
			render :ok
		end
	end

	class Next
		def get
			@@c.next
			render :ok
		end
	end

	class PlaynoN
		def get(pos)
			@@c.playid(pos)
			render :ok
		end
	end

	class Seek < R '/seek/(\d+)/(\d+)'
		def get(pos, sec)
			@@c.seek(pos, sec)
			render :ok
		end
	end
	
	class Addsong < R '/addsong/(.+)'
		def get(song)
			@@c.add(song[1...-1])
			redirect Index
		end
	end
	
	class Addalbum < R '/addalbum/(.+)'
		def get(a)
			tlist = @@c.find('album', a)
			for t in tlist
				@@c.add(t['file'])
			end
			redirect Index
		end
	end

	class Addartist < R '/addartist/(.+)'
		def get(a)
			tlist = @@c.find('artist', a)
			for t in tlist
				@@c.add(t['file'])
			end
			redirect Index
		end
	end

	class Update
		def get
			@@c.update
			render :ok
		end
	end

	class Togglerepeat
		def get
			@@c.repeat=!(@@c.repeat?)
			return @@c.repeat?.to_s
		end
	end

	class Togglerandom
		def get
			@@c.random=!(@@c.random?)
			return @@c.random?.to_s
		end
	end

	# JSON Status/Requests
	class Currentsong
		def get
			s = @@c.current_song
			# keys will be utf-8 encoded from librmpd
			# force this for the json lib to recognize it doesn't need to convert
			for k in ['artist', 'title', 'album', 'genre', 'file'] do
				if s.key? k then s[k].force_encoding('utf-8') end
			end
			return s.to_json
		end
	end

	class Status
		def get
			return @@c.status.to_json
		end
	end

	class Playtime
		def get
			return @@c.status['time']
		end
	end

	class Playlistding
		def get
			pl = @@c.playlist
			r = []
			for item in pl
				i = {}
				['pos', 'artist', 'album', 'title', 'time', 'file'].each do |key|
					i[key] = item[key]
					i[key].force_encoding('utf-8') if i[key].respond_to? :force_encoding
				end
				r += [i]
			end
			return r.to_json
		end
	end

	# Static Routes
	@@current_dir = File.expand_path(File.dirname(__FILE__))

	class JavaScripts < R '/js/(.*\.js)'
		def get(script_name)
			@headers['Content-Type'] = 'text/javascript'
			@headers['X-Sendfile'] = "#{@@current_dir}/js/#{script_name}"
		end
	end

	class StyleSheet < R '/style/style\.css'
		def get
			@headers['Content-Type'] = 'text/css'
			@headers['X-Sendfile'] = "#{@@current_dir}/style/style.css"
		end
	end

	class Image < R '/img/(.*)'
		def get(img_name)
			@headers['Content-Type'] = "image/#{File.extname(img_name)}"
			@headers['X-Sendfile'] = "#{@@current_dir}/img/#{img_name}"
		end
	end

	class Favicon < R '/favicon\.ico'
		def get
			@headers['Content-Type'] = "image/vnd.microsoft.icon"
			@headers['X-Sendfile'] = "#{@@current_dir}/img/favicon.ico"
		end
	end

	# Download/stream music
	@@music_dir = "/var/lib/mpd/music/"

	class Download < R '/dl/(.*)'
		def get(filename)
			if not ( filename.include? '..' or filename.include? '~' )
				f = @@music_dir + filename
				if File::file? ( f )
					# TODO find mimetype from file? flac? etc
					@headers['Content-Type'] = 'audio/mpeg'
					@headers['X-Sendfile'] = f
				else
					return "Too bad. File not found."
				end
			else
				return "You tryin' to hack the computer?? ;P"
			end
		end
	end

	class DownloadThis < R '/downloadthis'
		def get
			fn = @@c.current_song['file']
			redirect Download, fn
		end
	end

	class StreamPLFile < R '/streaming'
		def get
			@headers['Content-Type'] = 'text/playlist'
			@headers['X-Sendfile'] = "#{@@current_dir}/casperstream.pls"
		end
	end
end

module CampingMPC::Views
	# Index
	def stylesheetlink
		link :rel => 'stylesheet', :href => 'style/style.css', :type => 'text/css'
	end
	def scriptjslink
		script :type => 'text/javascript', :src => 'js/script.js'
		text "</script>"
	end
	def mochikitlink
		script :type => 'text/javascript', :src => 'js/MochiKit.js'
		text "</script>"
	end
	def scriptslink
		mochikitlink
		scriptjslink
	end
	def index
		html do
			head do
				title { text (@artist ? @artist + " - " : "") + "#{@title}#{@album ? " (" + @album + ") " : ""} - CampingMPC v0.3 (full ajax)" }
				text "<link rel='shortcut icon' href='/favicon.ico' />"
				stylesheetlink
				scriptslink
			end
			body.main! :onload => "init_info_framework(#{@t_elapsed},#{@t_total},#{@s['pos']},#{@playing.to_s},#{@repeat},#{@random})" do
				div.headerbar! do
					h1 :onclick => 'window.location.href="/downloadthis"' do text "#{@title}" end
					h2 { text "by <i>#{@artist}</i> from <i>#{@album}</i> #{@track}" }
				end
				div.controlbar! do
					div.progressbarcontainer! :onclick => 'do_seek(event)' do
						div.progressbartextlayer! { text " " }
						div.progressbar! { text "&nbsp;" }
						div.progressind! { text "&nbsp;" }
					end
					br
					text ['prev', 'play', 'pause', 'stop', 'next'].map { |b| "<img onclick='#{b}()' id='b_#{b}' src='/img/#{b}.png' />" }.join
				end
				div.toggles! do
					div.repeat! :onclick => 'toggledivclick(this,event)' do
						input :type => 'checkbox', :onclick => 'toggleclick(this,event); if(typeof(event.stopPropagation) != "undefined") { event.stopPropagation(); } if(typeof(event.cancelBubble) != "undefined") { event.cancelBubble(); }'
						img :src => '/img/repeat.png'
					end
					br
					div.random! :onclick => 'toggledivclick(this,event)' do
						input :type => 'checkbox', :onclick => 'toggleclick(this,event); if(typeof(event.stopPropagation) != "undefined") { event.stopPropagation(); } if(typeof(event.cancelBubble) != "undefined") { event.cancelBubble(); }'
						img :src => '/img/random.png'
					end
				end
				br
				ul.tab do			# link, image, title
					text [  ['playlist', 'current', 'playlist'],
							['filetree', 'browse', 'files'],
							['albumtree', 'cd24', 'albums'],
							['artisttree', 'artist24', 'artists'] ].map { |t| capture { text "<li><a href='/#{t[0]}' target='subframe'><img src='/img/#{t[1]}.png' /> #{t[2]}</a></li>" } }.join(" ")
					text "<li class='r'><a href='javascript:call=new XMLHttpRequest();call.open(\"GET\",\"/update\");call.onreadystatechange=function(){};call.send();' target='_top'><img src='/img/refresh.png' alt='update' /></a></li>"
				end
				iframe.subframe! :name => 'subframe', :width => '100%', :height => '500px', :src => '/playlist' do
					text ""
				end
				div.minilink! do
					a :href => 'javascript:switch_default_minimal_style();', :id => 'sw' do "switch to mini" end
					text " | "
					a :href => '#' do "admin" end
				end
				div.disclaimer! { text "DISCLAIMER: If you download a song that you do not own from this site, you agree to delete it within 24 hours." }
				div.copyright! { text "<a href='http://hasj-kebab.blogspot.com/search/label/campingmpc' target='_blank'>CampingMPC</a> v0.2 by SDC superb design+code" }
			end
		end
	end

	# Playlist
	def playlist
		html do
			head do
				title "CampingMPC"
				stylesheetlink
			end
			body.subframe do
				div.playlist do
					div.songheader! do
						span.plimg		{ text "&nbsp;" }
						span.plartist	{ text "Artist" }
						span.pltitle	{ text "Title" }
						span.pltime		{ text "Time" }
						span.pldlimg	{ text "&nbsp;" }
					end
					for item in @plinfo do
						div :class => 'song ' + (item['pos'] == @pos ? 'currentsong' : ''), :id => "pl#{item['pos']}", :onclick => "parent.playno(#{item['pos']})" do
							span.plimg        { img :src => '/img/musicfile.png' }
							span.plartist     item['artist']
							span.pltitle      item.fetch('title', ( item['file']['/'] ? (item['file'][item['file'].rindex('/')+1...item['file'].rindex('.')]) : item['file'][0...item['file'].rindex('.')] ))
							span.pltime       SecToTimeString(item['time']), :class => 'tracklen'
							span.pldlimg      { img :src => "/img/download16.png", :onclick => "window.location.href='/dl/#{item['file']}'" }
						end
					end
				end
			end
		end
	end

	# Filetree
	def filetree
		html do
			head do
				title 'CampingMPD'
				stylesheetlink
			end
			body.subframe do
				#text @ulftree
				img :src => '/img/lib.png'
				text " Root"
				br
				ul.tree do
					subtree(@ftree)
				end
			end
		end
	end
	def subtree(tree, path=[])
		if tree.length > 1
			for fn in tree[1..-1].sort
				li :class => ((fn == tree[1..-1].sort[-1]) && !(tree[0].length > 0) ? 'last' : '' ) do 
					img :src => '/img/musicfile.png'
					text " <a href='/addsong/\"#{path.map{|x|"/"+x}.join[1..-1]}#{path.length>0?"/":""}#{fn}\"' target='_top'><img src='/img/add.png'></a><a href='/dl/#{path.map{|x|"/"+x}.join[1..-1]}#{path.length>0?"/":""}#{fn}' target='_top'><img src='/img/download16.png'></a> #{fn[0...fn.rindex('.')]}"
					#a :href => "/addsong/\"#{path.map{|x|"/"+x}.join[1..-1]}#{path.length>0?'/':''}#{fn}\"", :target => '_top' do
						#img :src => '/img/add.png'
						#text fn[0...fn.rindex('.')]
					#end
				end
			end
		end
		for subdir in tree[0].keys.sort
			li :class => ( subdir == tree[0].keys.sort[-1] ? 'last' : '' ) do
				img :src => '/img/folder-music.png'
				text " " + subdir + " "
				a :href => "/addsong/\"#{path.map{|x|"/"+x}.join[1..-1]}#{path.length>0?'/':''}#{subdir}\"", :target => '_top' do
					img :src => '/img/add.png'
				end
				ul do
					subtree(tree[0][subdir], path + [subdir])
				end
			end
		end
	end

	# Albumtree
	def albumtree
		html do
			head do
				title 'CampingMPD'
				stylesheetlink
			end
			body.subframe do
				img :src => '/img/lib.png'
				text " All albums"
				br
				ul.tree do
					for album in @atree.keys.sort
						li :class => ( album==@atree.keys.sort[-1] ? 'last' : '' ) do
							#text "<img src='/img/cd16.png' /> #{( (album=='') ? 'Unknown Album' : album )} <a href='/addalbum/#{album}' target='_top'><img src='/img/add.png' /></a>"
							img :src => '/img/cd16.png'
							text " #{( (album=='') ? 'Unknown Album' : album )} "
							if album.length > 0
								a :href => "/addalbum/#{album}", :target => '_top' do
									img :src => '/img/add.png'
								end
							end
							ul do
								for track in @atree.fetch(album, [])
									li :class => ( (track==@atree[album][-1]) ? 'last' : '' ) do
										# too bad, you can't pass utf-8 string to a :href =>
										text "<img src='/img/musicfile.png' /> <a href='/addsong/#{track['file']}' target='_top'><img src='/img/add.png' /></a> #{track.fetch('title', track['file'][(track['file'].rindex('/')||-1)+1...track['file'].rindex('.')])}"
										#a :href => "/addsong/#{track['file']}", :target => '_top' do
											#img :src => '/img/add.png'
										#end
										#text " #{track.fetch('title', track['file'][(track['file'].rindex('/')||-1)+1...track['file'].rindex('.')])}"
									end
								end
							end
						end
					end
				end
			end
		end
	end

	# Artisttree
	def artisttree
		html do
			head do
				title 'CampingMPD'
				stylesheetlink
			end
			body.subframe do
				img :src => '/img/lib.png'
				text " All artists"
				br
				text @ularttree
			end
		end
	end

	# OK status (for ajax actions)
	def ok
		text "OK"
	end
end
