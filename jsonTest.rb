#!/usr/bin/env ruby

require 'json'
require 'kamelopard'
require 'open-uri'

include Kamelopard

kmlDir = 'kml'

TemplatePlacemarkKML = %(<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
  <LookAt>
    <longitude><%= longitude %></longitude>
    <latitude><%= latitude %></latitude>
    <altitude>0</altitude>
    <heading><%= heading %></heading>
    <tilt><%= tilt %></tilt>
    <range><%= range %></range>
    <gx:altitudeMode>Absolute</gx:altitudeMode>
  </LookAt>
</kml>
)
$abs_const = {  :heading => 0,
                :range => 1250, 
                :tilt => 63, 
                :altitude => 0, 
                :altitudeMode => 'absolute' 
}

json_file = File.read('buei.json')
json_hash = JSON.parse(json_file)

def makeTour(p)

  puts "here!"

  #data_filename = p["title"].gsub(/[, ]/,'-').gsub('--','-').downcase
  title = p[:title].gsub(',','')
  doc_name = "#{p[:title].gsub(/[, ']/,'-').gsub('--','-').downcase}"
  puts "Building #{title} Tour..."

  # name the Document using the data filename
  name_document = title 
  tourname = "#{doc_name} Tour"

  Document.new "#{doc_name}"

  # Create an AutoPlay folder with the Autoplay networklink
  name_folder 'AutoPlay'
  
  # ROSCOE Autoplay
  get_folder << Kamelopard::NetworkLink.new( URI::encode("http://localhost:8765/query.html?query=playtour=#{tourname}"), {:name => "Autoplay", :flyToView => 0, :refreshVisibility => 0} )

  # Name the Tour element
  name_tour    tourname 

  # Build KML Elements
  title = p[:title]
  latitude = p[:latitude] 
  longitude = p[:longitude]
  heading = $abs_const[:heading]
  range = $abs_const[:range]
  tilt = $abs_const[:tilt]

  # Build XML Doc for Kamelopard 
  renderer = ERB.new TemplatePlacemarkKML
  kml = XML::Document.string(renderer.result(binding))

  # FlyTo Point
  fly_to Kamelopard::LookAt.parse(kml), :duration => 6

  puts "Building #{title} KML..."

  # pause
  pause 1

  puts "Writing gx:Tour to file..."

  # output to the same name as the data file, except with .kml extension 
  outfile = [ doc_name,'kml' ].join('.')  
  write_kml_to outfile 

end    

puts "...reading JSON."
$points = []

json_hash.each do |d|
  case d
  when String
    next
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
            
            $points << {:title => title,
                        :heading => heading,
                        :latitude => location.fetch("latitude"),
                        :longitude => location.fetch("longitude")
                        }
          
          end
        else 
          puts "No pertinant keys found!"
        end
      end 
    end
  end
end

# Tour Dynamics

$points.each do |p|
  makeTour(p)
end

