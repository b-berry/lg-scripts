#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'

FileType=["kml","kmz"]
HostROS ="http://localhost" 
PortROS =":8765"
PathROS = "/query.html"
QueryROS = "?query=playtour="

$files=[]

# Set asset dir from command-line argument
if ARGV[0].nil?
    puts "ERROR: Please specify path to asset_storage."
    exit
else 
    path = ARGV[0]
end

def collectFiles(path)

    searchType = FileType.join(",")

    puts "Searching for #{searchType.upcase} files in #{path}"

    $files = Dir.glob("#{path}/**.{#{searchType}}")

end

def parseFiles
    
    $files.each do |file|

        # Test filetype 
        ftype = File.extname(file)
        ftype = `file #{file}`
        case ftype
        when /XML/
            # Open KML file
            doc = File.open(file) { |f| Nokogiri::XML(f) }
            convertFile(doc)
            writeFile(doc,file)
        #when ".kmz"
        when /Zip/
            unzipFile(file)
            #zipFile(doc,file)
        end    
    end
end

def convertFile(doc)

    networkLink = doc.css("NetworkLink") 
    # Skip file if no NetworkLink present
    return if networkLink.empty?
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
        # Confirm tourname
        if @tourname.nil? then
            puts "No Tourname Found! Skipping NetworkLink"
            return 
        end
        #queryRosString = URI.encode_www_form(QueryROS => @tourname) 	
        queryRosString = "#{QueryROS}#{@tourname}"
        # Modify Autoplay Url
        hrefRosReplace = URI.parse("#{HostROS}#{PortROS}#{PathROS}#{queryRosString}")
        puts "...modifying Url: #{hrefRosReplace}."
        networkLink.at_css("href").content = hrefRosReplace        	
    end
    return doc
end

def writeFile(doc,file)

    # Write modified changes
    #File.write(file, doc.to_xml)
    puts "...Writing modifications..."
    #File.open(file, 'w') { |f| f.print(doc.to_xml) }
    File.write(file, doc.to_xml)
    puts "...done."

end

def testFiles
    # Test results
    if $files.empty? 
        puts "...ERROR: No files found!"
        exit
    else
        # Report Findings.
        puts "...found #{$files.length} KML files." 
   end

end

def unzipFile(file)

    # RubyZip gem usage
    #require 'zip'

    #zip::File.open(file) do |kmz|
    #    kmls = kmz.glob('*.kml')
    #    kmls.each do |k|
    #        doc = k.get_input_stream.read
    #    end
    #end
    # or
    # doc = XML::Document.string(Zip::File.open("GROTour.kmz").glob('doc.kml').first.get_input_stream.read)

    # Unzip *.kml from file.kmz as File
    #kmls = []
    puts "Unpacking KMZ: #{file}..."
    kmls = `unzip -p -j #{file} doc.kml`

    # Test Unzip
    if kmls.empty? 
         puts "...Unpack failed, no doc.kml found."
    end
 
    #kmls.each do |k|
        # Open KML file
        #doc = XML::Document.string(kmls) { |f| Nokogiri::XML(f) }
        doc = Nokogiri::XML(kmls)

        unless doc.nil?
            puts "...OK."
            convertFile(doc)
        
            # Update file in archive
            zipFile(doc,file)
        end
    #end

end

def zipFile(doc,file)

    # Update doc.kml in zip archive
    `zip -u #{file} -j #{doc}`

end


### Run Time Operations Start Here ###

# Issue warning
puts "### WARNING!! ###"
puts "# Running this script will modify asset_files in #{path}"
puts "# Ctrl + z now to cancel operations"
puts

    sleep(2)

collectFiles(path)

testFiles

    sleep(2)

parseFiles

# Process KML files

