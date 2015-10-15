#!/usr/bin/env ruby
# vim:ts=4:sw=4:et:smartindent:nowrap
require 'kamelopard'
require 'kamelopard/spline'
require 'optparse'
require 'json'
#require 'pry'

include Kamelopard
include Kamelopard::Functions

#require_relative("foo.rb")

$options = {}
$styles = {}

# Set Defaults 
AutoplayTypes = %w(director ispaces roscoe)
FlightTypes = %w(flyto orbit spline)
GraphicTypes = %w(box screenOverlay)
RegionWidthDelta = 0.030
RegionHeightDelta = 0.030
RegionLOD = [ 1920,-1,0,0 ]
$abs_const = {  :heading => 0,
                :range => 1500, 
                :tilt => 67, 
                :altitude => 0, 
                :altitudeMode => 'absolute' 
}
$ex_case = [ "Moffett Federal Airfield", "Palo Alto Airport" ]

Template = %{
    <!DOCTYPE html>
    <html>
	<head>
        <meta charset="UTF-8">		
	    <style>
		body { background-color:white;
			   margin:40px;
		       width:980px
		     }
		h1 { font-family:"sans";
		     text-align:center  
		   }
		h2 { font-family:"sans";
		     text-align:center  
		   }
		img { width:900px; 
		      height:75px
		    }
		p { color:black; 
		    font-family:"sans";
		    text-align:justify;
		    width:900px
		  }
	    </style>  
	</head>    
	<title><%= title %> Overlay</title>
	<body>
    
	<img src="<%= logo %>" alt="logo">
	<h1><%= title %></h1>
	<h2><%= subtitle %></h2>
	<p><%= description %></p>

	</body>
    </html>
}

def getOpts

    # Parse Options
    OptionParser.new do |opts|
        # Set Defaults here
        $options[:autpolay] = 'director'
        $options[:infile] = 'doc.kml'
        $options[:inline] = 'true'

        opts.banner = "Usage: example.rb [options] -A {director,ispaces,roscoe} FILE"
        opts.on("-h", "--help", "Prints this help") do
            puts opts
            exit
        end
        opts.on("-aTYPE","--autoplay TYPE", AutoplayTypes, 
            "Build AutoPlay query using TYPE",
            " (#{AutoplayTypes})") do |aplay|
            $options[:autoplay] = aplay
        end
        opts.on("-fTYPE","--flight TYPE", FlightTypes, 
            "Build flight dynamics using TYPE",
            " (#{FlightTypes})") do |flight|
            $options[:flight] = flight
        end
        opts.on("-gTYPE","--graphic TYPE", GraphicTypes, 
            "Build graphics using TYPE",
            " (#{GraphicTypes})") do |gtype|
            $options[:graphic] = gtype
        end
        opts.on("-o", "--override h,r,t", Array, "Override abstract view: heading,tilt,range") do |override|
            $options[:override] = override
            # Modify w/ overrides
            unless $options[:override].nil? 
                $abs_const[:heading] = override[0]
                $abs_const[:range] = override[1]
                $abs_const[:tilt] = override[2]
            end
            puts "...Override abstract_view: #{$abs_const}."
        end
        opts.on("-r", "--regions", "Build tour w/ Regions") do |regions|
            $options[:regions] = true 
        end
        opts.on("-w", "--write-each", "Build [flyto, orbit] tour for each placemark") do |write|
            $options[:inline] = false 
        end
    end.parse!
   
    # Import :styleSheet 
    #unless $options[:styleSheet] == nil
    #    require_relative($options[:styleSheet])
    #end 

end

def makeAutoplay

    # Set current attributes
    name_document = $data_attr[:nameDocument]
    tourname = $data_attr[:tourName]

    # Create an AutoPlay folder with the Autoplay networklink
    name_folder 'AutoPlay'
    
    case $options.fetch(:autoplay)
        when "ispaces"
            # ISpaces Autoplay
            get_folder << Kamelopard::NetworkLink.new( URI::encode("http://localhost:9001/query.html?query=playtour=#{tourname}"), {:name => "Autoplay", :flyToView => 0, :refreshVisibility => 0} )
        when "director"
            # Director Autoplay
            get_folder << Kamelopard::NetworkLink.new( URI::encode("http://localhost:81/change.php?query=playtour=#{tourname}\&amp;name=#{name_document}"), {:name => "Autoplay", :flyToView => 0, :refreshVisibility => 0} )
        when "roscoe"
            # ROSCOE Autoplay
            get_folder << Kamelopard::NetworkLink.new( URI::encode("http://localhost:8765/query.html?query=playtour=#{tourname}"), {:name => "Autoplay", :flyToView => 0, :refreshVisibility => 0} )
        else
            puts "No system architecture specified"
            puts "... using default 'Director'"
            # Director Autoplay
            get_folder << Kamelopard::NetworkLink.new( URI::encode("http://localhost:81/change.php?query=playtour=#{tourname}\&amp;name=#{name_document}"), {:name => "Autoplay", :flyToView => 0, :refreshVisibility => 0} )
    end

end

def makeOverlay(p)

	renderer = ERB.new Template
	matches = p[:description].match(/(^.*\(\w+\))\s+(.*?)\n(.*)/m)
    name = p[:name].gsub(' ','-').downcase
	title = matches[1]
	subtitle = matches[2]
	description = matches[3]
    logo = "logo.jpg"
	html_file = "files/#{name}.html"
	png_file  = "files/#{name}.png"

	html = renderer.result(binding)
	#p html
	File.write(html_file, html)
	`wkhtmltoimage --width 980 --disable-smart-width "#{html_file}" "#{png_file}"`

    # Make screenOverlay
    puts "...populating w/ overlay: #{png_file}"
    get_folder << screenoverlay(
        :href => "#{png_file}",
        :screenXY  => xy(0.5, 0.95),
        :overlayXY => xy(0.5, 1),
        :size => xy(-1, -1)
    )

end


def makeRegions(infile)

    # Process document name
    doc_name = "#{infile.gsub(/[-_]/,' ').split.map(&:capitalize).join(' ').chomp(".kml")}"
    puts "Building #{doc_name} Regionation..."

    # name the Document using the data filename
    name_document = "#{doc_name} Regionation"

    Document.new "#{name_document}"

    i = 1
    $points.each do | p, v |
        # Build KML Regions
        puts "Generating Region#{i}: #{p[:name]} Overlay"
 
        # Create new folder for each Region && screenOverlay 
        Kamelopard::Folder.new("#{p[:name]}")

        # Make Region instance
        if not (p[:latitude].nil? or p[:longitude].nil?)
	    	#binding.pry
            # Test Case for $ex_case
            if $ex_case.include? p[:name]
                get_folder << Kamelopard::Region.new(
                    :latlonaltbox => Kamelopard::LatLonBox.new(
                        p[:latitude].to_f + RegionHeightDelta.to_f / 2, 
                        p[:latitude].to_f - RegionHeightDelta.to_f / 2,
                        p[:longitude].to_f + RegionWidthDelta.to_f / 2, 
                        p[:longitude].to_f - RegionWidthDelta.to_f / 2,
                    ),
                    :lod => Kamelopard::Lod.new(*RegionLOD)
                    #:lod => Kamelopard::Lod.new(1000,-1,1000,0)
                )
            else 
                get_folder << Kamelopard::Region.new(
                    :latlonaltbox => Kamelopard::LatLonBox.new(
                        p[:latitude].to_f + RegionHeightDelta.to_f, 
                        p[:latitude].to_f - RegionHeightDelta.to_f,
                        p[:longitude].to_f + RegionWidthDelta.to_f, 
                        p[:longitude].to_f - RegionWidthDelta.to_f,
                    ),
                    :lod => Kamelopard::Lod.new(*RegionLOD)
                    #:lod => Kamelopard::Lod.new(1000,-1,1000,0)
                )
            end
        end
        
        puts "...adding overlay to region folder"

        makeOverlay(p)

        puts "...done."
        i += 1
    end

    puts "Writing Regions to file..."

    # output to the same name as the data file, except with .kml extension
    puts "doc_name is #{doc_name} of class: #{doc_name.class}"
    region_file = "#{doc_name.gsub(' ','-').downcase}-regions.kml"
    puts "region_file is #{region_file} of class: #{region_file.class}"
    write_kml_to region_file

    puts "...Done."

    sleep(2)

    puts "..zipping regionation files..."
    `zip #{region_file.chomp('.kml')}.kmz  -r #{region_file} files/`
    puts "...done!"
 
end

def collectPoints(infile)

    # Test infile TYPE
    infile_attr = infile.split('.')

    infile_type = infile_attr.last

    case infile_type
        when "kml"
    
            # Collect points from KML file
            puts "...reading KML..."
            $points = []
            each_placemark(XML::Document.file(ARGV[0])) do |p,v|
                unless $options[:override].nil?
                    # Override infile abstract view
                    v[:heading] = $abs_const.fetch(:heading)
                    v[:range] = $abs_const.fetch(:range) 
                    v[:tilt] = $abs_const.fetch(:tilt)
                end 
                $points << v
            end
            puts "...done."

        when "json"

            # Collect points from JSON file
            puts "...reading JSON..."
            $points = []
            # Do things
            
            puts "...done."

        else
            
            # Handle Error and exit
            puts "...Cannot parse infile type."
            puts "Aborting!"
            exit

    end

end

def makeFlyto

    # fly to each point
    $points.each do |p|

        # Create new Doc if user specified --each-write
        unless $options[:inline]

            # Get |p| attributes 
            modAttr(p)
            
            nameDoc
 
            makeAutoplay

            # Name the Tour element using the data filename
            name_tour     "#{$data_attr[:tourName]}"

        end

        # fly to each point
        fly_to make_view_from(p), :duration => 6

        # pause
        pause 4

            
        # Write KML if user specified --each-write
        unless $options[:inline]

            tourname = $data_attr[:tourName]
            writeTour 

        end
    end

end

def makeOrbit

    # fly to each point
    $points.each do |p|

        # Create new Doc if user specified --each-write
        unless $options[:inline]

            # Get |p| attributes 
            modAttr(p)
            
            nameDoc
 
            makeAutoplay

            # Name the Tour element using the data filename
            name_tour     "#{$data_attr[:tourName]}"

        end

        # fly to each point
        fly_to make_view_from(p), :duration => 6

        # orbit around "p", which is a kamelopard point() using values from the first placemark in the data file
        f = make_view_from(p)
        orbit( f, p[:range], p[:tilt], p[:heading].to_f, p[:heading].to_f + 280, {:duration => 37, :step => 10, :already_there => true} )

        # pause
        pause 1.5 

        # Write KML if user specified --each-write
        unless $options[:inline]

            tourname = $data_attr[:tourName]
            writeTour 

        end
    end

    # Special Case
    unless ARGV[1].nil?	
        puts "Handling secondary file..."
        alt_marks = []
        # Read alt file	
        each_placemark(XML::Document.file(ARGV[1])) do |p,v|
            #v[:range] = 2000 
            #v[:tilt] = 71
            #v[:altitude] = 0 
            alt_marks << v
        end

        # Fly to 1st point
        fly_to make_view_from(alt_marks.first), :duration => 3

        # pause
        pause 2

        puts "...done."
    end
	
end

def makeSpline

    # Define Spline
    puts "Generating spline path..."
    sp = SplineFunction.new($points.length.to_f)

    # Iniitiate spline array && screenOverlay regionation 
    m = 0
    #(0..$points.length-1).step(2) do |i| 
    (0..$points.length-1).step(1) do |i| 
        #if i.even?

        # Initiate Spline Construction
        sp.add_control_point [ $points[i][:latitude].to_f,
               $points[i][:longitude].to_f,
               $points[i][:altitude].to_f,
               $points[i][:range].to_f
               ], 10    

        # Construct Regions
        #makeRegion(i)
    end

    # Build spline dynamics
    a = make_function_path( 10 * $points.length.to_f,
    :altitudeMode => $abs_const[:altitudeMode], :tilt => $abs_const[:tilt].to_f, :show_placemarks => 0,
    :multidim => [ [ sp, [ :latitude, :longitude, :altitude, :range ] ] ]
    )

    spline_points = []
    a[0].each do |p|
    spline_points << [p.longitude, p.latitude, p.altitude]
    end

    tour_from_points spline_points, { :exaggerate => 3 }

    # pause
    pause 4

end

def makeTour    

    # Make autoplay link
    makeAutoplay

    # Name the Tour element using the data filename
    name_tour     "#{$data_attr[:tourName]}"

    # Initiate gx:Tour Dynamics
    case $options.fetch(:flight)

        when "flyto"
            makeFlyto

        when "orbit"
            makeOrbit

        when "spline"
            makeSpline 

        else
            puts "No tour :flight dynamic specified!"
    end

    writeTour if $options[:inline]
    
end

def nameDoc

    #Document.new "#{name_document}"
    Document.new "#{$data_attr[:nameDocument]}"

end

def modAttr(p)

    # Process document name
    doc_name = "#{p[:name].gsub(/[-_]/,' ').split.map(&:capitalize).join(' ')}"
    puts "Building #{doc_name} #{$options.fetch(:flight).capitalize}..."

    # name the Document using the data filename
    name_document = "#{doc_name} #{$options.fetch(:flight).capitalize}"
    tourname = name_document.gsub(' ','-').downcase

    $data_attr[:docName] =  doc_name
    $data_attr[:nameDocument] = name_document
    $data_attr[:tourName] = tourname

end

def setAttr(infile)

    $data_attr = {} 

    # Process document name
	data_filename = File.basename(infile,'.*')
    doc_name = "#{data_filename.gsub(/[-_]/,' ').split.map(&:capitalize).join(' ').chomp(".kml")}"
    puts "Building #{doc_name} #{$options.fetch(:flight).capitalize}..."

    # name the Document using the data filename
    name_document = "#{doc_name} #{$options.fetch(:flight).capitalize}"
    tourname = "#{name_document.gsub(' ','-').downcase}-#{$options.fetch(:flight)}"

    $data_attr = { :dataFilename => data_filename, :docName => doc_name, :nameDocument => name_document, :tourName => tourname }

end

def writeTour

    puts "Writing gx:Tour to file..."

    # Set current attributes
    tourname = $data_attr[:tourName]

    # output to the same name as the data file, except with .kml extension
    outfile = [ tourname, 'kml' ].join('.')
    write_kml_to outfile

    puts "...Done."

end

#### Script Execution starts Here  ####
# Parse CLI options
getOpts

# data filename should be the first argument ./me ./path/to/data-file
infile = ARGV[0]

# Initiate attributes
setAttr(infile)

# Read $infile
collectPoints(infile)

# Build gx:Tour if flight type specified
if FlightTypes.include? $options[:flight] 
    #makeTour(infile)
    makeTour
end

sleep(1)

# Set up dynamic content KMZ
if $options[:regions] 
    puts "Generating Regions..."
    sleep(1)
    makeRegions(infile)
else
    puts "No additional constructions indicated..."
end

puts "Finished!"



