#!/usr/bin/env ruby
# vim:ts=4:sw=4:et:smartindent:nowrap
require 'csv'
require 'etc'
require 'fileutils'
require 'json'
require 'kamelopard'
require 'kamelopard/spline'
require 'logger'
require 'optparse'
require 'securerandom'

include Kamelopard
include Kamelopard::Functions


$log = Logger.new('./batchTour.log')
$log.level = Logger::WARN

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
HostROS ="http://localhost" 
PortROS =":8765"
PathROS = "/query.html"
QueryROS = "?query=playtour="

$abs_const = {  :heading => 0,
                :range => 1500, 
                :tilt => 67, 
                :altitude => 0, 
                :altitudeMode => 'absolute' 
}
$ex_case = [ "Moffett Federal Airfield", "Palo Alto Airport" ]

TemplateOverlayKML = %(<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
  <Document>
    <ScreenOverlay id="<%= name %>-id">
        <name><%= name %></name>
        <Icon><href><%= name %>.png</href></Icon>
        <overlayXY x="<%= so_xy[0] %>" y="<%= so_xy[2] %>" xunits="<%= so_xy[1] %>" yunits="<%= so_xy[3] %>"/>
        <screenXY x="<%= so_xy[4] %>" y="<%= so_xy[6] %>" xunits="<%= so_xy[5] %>" yunits="<%= so_xy[7] %>"/>
        <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
        <size x="<%= so_xy[8] %>" y="<%= so_xy[10] %>" xunits="<%= so_xy[9] %>" yunits="<%= so_xy[11] %>"/>
    </ScreenOverlay>
  </Document>
</kml>
)

TemplateOverlayHTML = %{
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
        $options[:assetdir] = './'
        $options[:autpolay] = 'director'
        $options[:infile] = 'doc.kml'
        $options[:inline] = 'true'
        $options[:orbit] = %w(90 30 7)
        $options[:overlayXY] = %w(0 fraction 1 fraction 0 fraction 1 fraction -1 fraction -1 fraction)
        $options[:placemarks] = false 

        opts.banner = "Usage: example.rb [options] -A {director,ispaces,roscoe} FILE"
        opts.on("-h", "--help", "Prints this help") do
            STDOUT.puts opts
            exit
        end
        opts.on("-aTYPE","--autoplay TYPE", AutoplayTypes, 
            "Build AutoPlay query using TYPE",
            " (#{AutoplayTypes})") do |aplay|
            $options[:autoplay] = aplay
        end
        opts.on("-d", "--asset-dir PATH","Set asset write-to path", 
            " Default inline: ie ./") do |dir|
            $options[:assetdir] = dir
        end
        opts.on("-fTYPE","--flight TYPE", FlightTypes, 
            "Build flight dynamics using TYPE", 
            " (#{FlightTypes})",
            " (orbit defaults: #{$options[:orbit]})") do |flight|
            $options[:flight] = flight
        end
        opts.on("-gTYPE","--graphic TYPE", GraphicTypes, 
            "Build graphics using TYPE",
            " (#{GraphicTypes})") do |gtype|
            $options[:graphic] = gtype
        end
        opts.on("-i", "--iconStylye IMG","Set path to placemark icon", 
            " Default: nil") do |icon|
            $options[:iconStyle] = icon
        end
        opts.on("-o", "--override a,h,r,t", Array, 
            "Override abstract view: alt,heading,range,tilt") do |override|
            $options[:override] = override
            # Modify w/ overrides
            unless $options[:override].nil? 
                $abs_const[:altitude] = override[0]
                $abs_const[:heading] = override[1]
                $abs_const[:range] = override[2]
                $abs_const[:tilt] = override[3]
            end
            STDERR.puts "...Override abstract_view: #{$abs_const}."
        end
        opts.on("-p", "--placemarks","Build KML placemarks only", 
            " Default: nil") do |pmrk|
            $options[:placemarks] = true
        end
        opts.on("-O", "--overrideOrbit t,d,s", Array, 
            "Override abstract view: theta,duration,step") do |overrideOrbit|
            # Modify w/ overrides
            if overrideOrbit.length == 3 
                puts "User Specified Orbit Override: #{overrideOrbit}"
               $options[:orbit] = overrideOrbit
            else
               STDERR.puts "...Invalid Orbit dynamics specified"
               exit 1
            end
            STDOUT.puts "...Override Orbit dynamics: #{$options[:orbit]}."
        end
        opts.on("-r", "--regions", "Build tour w/ Regions") do |regions|
            $options[:regions] = true 
        end
        opts.on("-s", "--screenOverlay PATH", "Build KMZ overlays from images in PATH") do |path|
            $options[:screenOverlay] = true
            $options[:images] = path
        end
        opts.on("-x", "--xy-overlay overlayXY(),screnXY(),sizeXY()", Array,
            "Overide default ScreenOverlay anchor: #{$options[:overlayXY]}") do |so|
            $options[:overlayXY] = so
            STDOUT.puts "...Override ScreenOverlay anchor: #{$options[:screenXY]}"
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
            STDERR.puts "No system architecture specified"
            STDERR.puts "... using default 'Director'"
            # Director Autoplay
            get_folder << Kamelopard::NetworkLink.new( URI::encode("http://localhost:81/change.php?query=playtour=#{tourname}\&amp;name=#{name_document}"), {:name => "Autoplay", :flyToView => 0, :refreshVisibility => 0} )
    end

end


def makeOverlayKML

    # Collect Images
    images=[]
    images=Dir.glob("#{$options[:images]}/**.{jpg,png}")

    # Build KML from template
    images.each do |i|
        renderer = ERB.new TemplateOverlayKML
        filename = File.basename(i)
        filetype = File.extname(filename)
        #name = filename.gsub(' ','-').downcase
        name = File.basename(i,File.extname(i)).gsub(' ','-').downcase
        so_xy = $options[:overlayXY]
        kml_file = "#{$options[:images]}/#{name}.kml"

        STDOUT.puts "Building #{name} KML..."
        kml = renderer.result(binding)
        File.write(kml_file, kml)
        STDOUT.puts "...done."
        STDOUT.puts "..zipping #{name} KML..."
        `zip #{kml_file.chomp('.kml')}.kmz -j #{kml_file} #{i}`
        STDOUT.puts "...done."
 
    end
end


def makeOverlayHTML(p)

  renderer = ERB.new TemplateOverlayHTML
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
    STDOUT.puts "...populating w/ overlay: #{png_file}"
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
    STDOUT.puts "Building #{doc_name} Regionation..."

    # name the Document using the data filename
    name_document = "#{doc_name} Regionation"

    Document.new "#{name_document}"

    i = 1
    $points.each do | p, v |
        # Build KML Regions
        STDOUT.puts "Generating Region#{i}: #{p[:name]} Overlay"
 
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
        
        STDOUT.puts "...adding overlay to region folder"

        makeOverlayHTML(p)

        STDOUT.puts "...done."
        i += 1
    end

    STDOUT.puts "Writing Regions to file..."

    # output to the same name as the data file, except with .kml extension
    STDOUT.puts "doc_name is #{doc_name} of class: #{doc_name.class}"
    region_file = "#{doc_name.gsub(' ','-').downcase}-regions.kml"
    STDOUT.puts "region_file is #{region_file} of class: #{region_file.class}"
    write_kml_to region_file

    STDOUT.puts "...Done."

    sleep(2)

    STDOUT.puts "..zipping regionation files..."
    `zip #{region_file.chomp('.kml')}.kmz  -r #{region_file} files/`
    STDOUT.puts "...done!"
 
end

def makeKMZ(filename,dirname)

    STDOUT.puts "..zipping regionation files..."
    `zip #{filename.chomp('.kml')}.kmz  -r #{filename} files/`
    STDOUT.puts "...done!"

end

def collectPoints(infile)

    # Test infile TYPE
    infile_attr = infile.split('.')

    infile_type = infile_attr.last.downcase

    case infile_type
        when "csv"

            # Collect points from CSV file
            STDOUT.puts "...reading CSV..."
            header = []
            $points = []
            firstline = true
            # Gather data points
            CSV.foreach(infile) do |line|
                if firstline  
                    firstline = false
                    # Set header info
                    header << line.map{|l| l.chomp}
                    next
                end

                # Build Hash Collection
                #myLine = Hash[header.collect {|v| [v.gsub(' ','-').downcase,line[header.index(v).to_f]]}]

                 # Skip missing lat/lon  
                if line[14].nil? or line[15].nil?
                    next
                end

                unless $options[:override].nil?
                    # Override infile abstract view
                    heading = $abs_const.fetch(:heading)
                    range = $abs_const.fetch(:range) 
                    tilt = $abs_const.fetch(:tilt)
                end 


                # $points << line.map{|data| {
                #     line.each do |val|
                #         index = line.index(val)
                #         ":#{header[index]}" => val}}
                #     end
                
                # Test for lat/long
                #if myLine.key?("lat*") and myLine.key?("lng") 

                #$points << myLine

                # JLL Points Map
                $points << {
                    :city       => line[0],
                    :country    => line[1],
                    :name       => line[2],
                    :vendor     => line[3],
                    :vCapital   => line[4],
                    :sBroker    => line[5],
                    :purchaser  => line[6],
                    :pCapital   => line[7],
                    :bBroker    => line[8],
                    :year       => line[9],
                    :quarter    => line[10],
                    :price      => line[11],
                    :address    => line[12],
                    :sector     => line[13],  
                    :latitude  => line[14].to_f,
                    :longitude => line[15].to_f,
                    :heading   => heading.to_f,
                    :range     => range.to_f,
                    :tilt      => tilt.to_f
                }

            end

            # Find geodatas

        when "kml"
    
            # Collect points from KML file
            STDOUT.puts "...reading KML..."
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
            STDOUT.puts "...done."

        when "json"

            # Collect points from JSON file
            STDOUT.puts "...reading JSON..."
            $points = []
            # Do things
            json_file = File.read(ARGV[0])
            json_hash = JSON.parse(json_file)
            
           json_hash.each do |d|
             parseJson(d)
           end
 
            # Search JSON for:
            #title = parseJson(json_hash,title)
            #latitude = parseJson(json_hash,latitude)
            #longitude = parseJson(json_hash
            STDOUT.puts "...done."

        when "txt"

            # Collect points from queries.txt type file
            STDOUT.puts "...reading TXT..."
            q = []

            txt_file = File.read(ARGV[0])
            txt_file.each_line do | line |
                query = line.split("@")
                q << {:planet => query[0], :name => query[1], :flytoview => query[2].sub("flytoview=","").chomp}
            end

            parseTxt(q)

        else
            
            # Handle Error and exit
            STDERR.puts "...Cannot parse infile type."
            STDERR.puts "Aborting!"
            exit
    end
end


def parseJson(d)

    # Special Case JSON Parser - not gerneralized
    case d
      when String
        #next
      when Array
        d.each do |a|
          case a
          when String
            next
          when Array
            next
          when Hash
            if a.has_key?("points")
              a.fetch("points").each do |p|
                # Collect data
                title = p.fetch("title")
                heading = p.fetch("heading")
                location = p.fetch("location")
                STDOUT.puts "Found: #{title},#{heading},#{location}"

                $points << {:title => title,
                            :heading => heading,
                            :latitude => location.fetch("latitude"),
                            :longitude => location.fetch("longitude")
                           } 

              end
            else
              STDERR.puts "No pertinant keys found!"
            end
          end
        end
    end

end

def parseTxt(q)

    # Build Tours per Location
    q.each do | geo |
        # Skip Location if not earth
        next unless geo[:planet] == "earth"
        # Continue building tour
        gname = geo[:name]
        name_doc = gname
        tourname = "#{gname} Tour"
        file_name = gname.sub(" ","-").downcase
        #tour_doc = Kamelopard::Document.new "#{name_doc}", :filename => file_name

        modAttr(geo)

        #$data_attr[:docName] =  doc_name
        #$data_attr[:nameDocument] = name_document
        #$data_attr[:tourName] = tourname

        STDOUT.puts "...building Tour: #{$data_attr[:tourName]}"

        nameDoc

        #$data_attr[:nameDocument] = "#{name_doc}"
        #$data_attr[:tourName] = "#{tourname}".gsub(' ','-').downcase

        # Make Autoplay link
        #makeAutoplay

        # fly to each point
        # Process XML :flyto
        xml_str = geo.fetch(:flytoview)
        # Convert to Placemark String
        xml_plmrk_str = "<kml xmlns=\"http://www.opengis.net/kml/2.2\" xmlns:gx=\"http://www.google.com/kml/ext/2.2\" xmlns:kml=\"http://www.opengis.net/kml/2.2\"><Document><Placemark>#{xml_str}</Placemark></Document></kml>"
        # Create XML Document
        xml_doc = XML::Parser.string(xml_plmrk_str).parse
        #each_placemark(XML::Document.file("#{xml_plmrk_str}")) do |p,v|

        $points = []
        each_placemark(xml_doc) do |p,v|
            $points << v
        end
        
        $points.each do | flyto |

            makeTour

            #fly_to make_view_from(flyto), :duration => 4

            # pause
            #pause 2
        end
        
        writeTour

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
    $points.each_with_index do |p,i|

        # Set orbit dynamics
        init = $options[:orbit][0].to_f
        dur = $options[:orbit][1].to_f
        step = $options[:orbit][2].to_f

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
        orbit( f, p[:range], p[:tilt], p[:heading].to_f, p[:heading].to_f + init, {:duration => dur, :step => step, :already_there => true} )

        # pause
        pause 4 

        # Special Case
        unless ARGV[1].nil? 
            makeSecond(i)
        end

        # Write KML if user specified --each-write
        unless $options[:inline]

            tourname = $data_attr[:tourName]
            writeTour 

        end
    end

end

def makeSecond(i)

    STDOUT.puts "...Handling secondary file: #{ARGV[1]}"
    alt_marks = []
    # Read alt file 
    each_placemark(XML::Document.file(ARGV[1])) do |u,v|
        #v[:range] = 2000 
        #v[:tilt] = 71
        #v[:altitude] = 0 
        alt_marks << v
    end
    
    if alt_marks[i].nil? 
        STDERR.puts "...No Placemark at location: #{i}. Skipping."
    else
        # Fly to 1st point
        fly_to make_view_from(alt_marks[i]), :duration => 3

        # pause
        pause 4

        STDOUT.puts "...done."
    end

end

def makeSpline

    # Define Splinea
    STDOUT.puts "Generating spline path..."
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

def makePlacemarks

    # Create KML Document
    nameDoc
    name_folder = "#{$data_attr[:tourname]}"

    # Make Placemark Style
    pl_style = style(:icon => iconstyle("#{$options[:iconStyle]}", :scale => 3.5, :hotspot => xy(0.5,0)), :label => labelstyle(0, :color => 'ff5e9cbc'))

    $points.each do |pmark|

        name = pmark[:name].to_s
        lat  = pmark[:latitude].to_f
        lng  = pmark[:longitude].to_f

        # Store loc info 
        get_folder << placemark(name, :geometry => point(lng,lat,75,:relativeToGround), :styleUrl => pl_style)

    end
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
            STDERR.puts "No tour :flight dynamic specified!"
    end

    writeTour if $options[:inline]
    
end

def nameDoc

    #Document.new "#{name_document}"
    Document.new "#{$data_attr[:nameDocument]}"

end

def modAttr(p)

    # Process document name
    if p[:name].nil?
        p[:name] = "Nil-Name-#{SecureRandom.urlsafe_base64}"
    end

    doc_name = "#{p[:name].gsub(/[-_&\/:]/,' ').gsub(/[(,)]/,' ').gsub(/\<(.*)\>/,'').split.map(&:capitalize).join(' ').to_str}"

    flightType = $options.fetch(:flight)

    STDOUT.puts "Building #{doc_name} #{flightType.capitalize}..."

    # name the Document using the data filename
    name_document = "#{doc_name} #{flightType.capitalize}"
    tourname = name_document.gsub(' ','-').gsub('--','-').downcase

    $data_attr[:docName] =  doc_name
    $data_attr[:nameDocument] = name_document
    $data_attr[:tourName] = tourname

end

def setAttr(infile)

    $data_attr = {} 

    # Process document name
    data_filename = File.basename(infile,'.*')
    doc_name = "#{data_filename.gsub(/[-_]/,' ').split.map(&:capitalize).join(' ').chomp(".kml")}"

    # Handle document intent    
    if $options[:placemarks] 

        STDOUT.puts "Building #{doc_name} KML..."

        # name the Document using the data filename
        name_document = "#{doc_name} Placemarks"
        tourname = "#{name_document.gsub(' ','-').downcase}"

    else

        flightType = $options.fetch(:flight)
        STDOUT.puts "Building #{doc_name} #{flightType.capitalize}..."

        # name the Document using the data filename
        name_document = "#{doc_name} #{flightType.capitalize}"
        tourname = "#{name_document.gsub(' ','-').downcase}"
    end

    $data_attr = { :dataFilename => data_filename, :docName => doc_name, :nameDocument => name_document, :tourName => tourname }

end

def writeTour

    STDOUT.puts "Writing gx:Tour to file..."

    # Set current attributes
    tourname = $data_attr[:tourName]

    # output to the same name as the data file, except with .kml extension
    outfile = "#{$options[:assetdir]}/#{tourname}.kml"
    write_kml_to outfile

    STDOUT.puts "...Done."

end

#### Script Execution starts Here  ####
# Parse CLI options
getOpts

# data filename should be the first argument ./me ./path/to/data-file
infile = ARGV[0]

unless infile.nil?
    # Initiate attributes
    setAttr(infile)

    # Read $infile
    collectPoints(infile)

    # Test assets writeTo dir
    unless Dir.exists?($options[:assetdir])
       FileUtils.mkdir_p "#{$options[:assetdir]}"
    end

    # Build gx:Tour if flight type specified
    #if FlightTypes.include? $options[:flight] 
    #    makeTour
    #else
    if $options[:placemarks]
        makePlacemarks
        writeTour
    else
        makeTour
    end

    sleep(1)

    # Set up dynamic content KMZ
    if $options[:regions] 
        STDOUT.puts "Generating Regions..."
        sleep(1)
        makeRegions(infile)
        STDOUT.puts "...done!"
    else
        STDOUT.puts "No additional constructions indicated..."
    end 
end

if $options[:screenOverlay]
    STDOUT.puts "Generating Overlays..."
    makeOverlayKML
    STDOUT.puts "...done!"
end

STDOUT.puts "Finished!"
