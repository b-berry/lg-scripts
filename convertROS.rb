#!/usr/bin/env ruby

require 'etc'
require 'nokogiri'
require 'open-uri'

user=Etc.getlogin

pathSrc="/home/#{user}/src"
projSrc="/lg-kml/space_exploration/"
#projSrc="/lg-google-org"
fileType="kml"

HostROS ="http://localhost" 
PortROS =":8765"
PathROS = "/query.html"
QueryROS = "?query=playtour="

# Collect files
puts "Searching #{pathSrc}#{projSrc}/ for #{fileType.upcase} files..."
puts

filesKML=[]
filesKML=Dir.glob("#{pathSrc}#{projSrc}/**/*.#{fileType}")

# Test results
if filesKML.empty? 
    puts "No files found!"
    exit
end

# Report Findings.
puts filesKML
puts "Found #{filesKML.length} KML files." 

n = 0
# Operate over files
filesKML.each do |file|
    # Testing
    #if [ n > 0 ]
    #    break
    #end

    puts "...editing #{file}:"
    doc = File.open("#{file}") { |f| Nokogiri::XML(f) }
    networkLink = doc.css("NetworkLink") 
	# Skip file if no NetworkLink present
	next if networkLink.empty?
	# Get networkLink Name
	networkLinkName = networkLink.css("name")
	if networkLinkName.css("name").text  == "Autoplay" then 
		# Extract Director Url
		href = URI.parse(networkLink.css("href").text)
		host = href.host
		port = href.port
		path = href.path
		query = href.query
		# Extract #{tourname}
        if [ href.query.length > 1 ] then
		    href.query.split("&").each do |query|
			    playtourTest = query.split("=").index("playtour")
			    next if playtourTest.nil?
			    @tourname = query.split("=")[playtourTest.to_f + 1]
	        end
        else
		    playtourTest = query.split("=").index("playtour")
			@tourname = query.split("=")[playtourTest.to_f + 1]
        end
        puts @tourname
        # Confirm tourname
        if @tourname.nil? then
            puts "No Tourname Found! Skipping NetworkLink"
            next
        end
	    #queryRosString = URI.encode_www_form(QueryROS => @tourname) 	
        queryRosString = "#{QueryROS}#{@tourname}"
        # Modify Autoplay Url
        hrefRosReplace = URI.parse("#{HostROS}#{PortROS}#{PathROS}#{queryRosString}")
        puts "...modifying Url: #{hrefRosReplace}."
        networkLink.at_css("href").content = hrefRosReplace        	
	end

    # Write modified changes
    #File.write(file, doc.to_xml)
    puts "...Writing modifications..."
	File.open(file, 'w') { |f| f.print(doc.to_xml) }
    puts "...done."
    
    # Testing
    #n = n + 1
end



