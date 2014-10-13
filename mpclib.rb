def SecToTimeString(secstr)
	secs = secstr.to_i
	xmin, xsec = secs / 60, secs % 60
	if xmin > 60
		xhour, xmin = xmin / 60, xmin % 60
		return sprintf("%d:%02d:%02d", xhour, xmin, xsec)
	else
		return sprintf("%d:%02d", xmin, xsec)
	end
end

def TreeList(full_list = [])
	tree_list = [ {} ]
	for item in full_list
		path = item.split("/")
		# find and/or build dir structure accordingly
		workingdir = tree_list
		wdstring = "tree_list"
		for subdir in path[0...-1]
			if not workingdir[0].key?(subdir)
				workingdir[0][subdir] = [ {} ]
			end
			workingdir = workingdir[0][subdir]
			wdstring += "[0][\"#{subdir}\"]"
		end
		eval("#{wdstring} += [path[-1]]")
	end
	return tree_list
end
