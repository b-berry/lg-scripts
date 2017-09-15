#!/usr/bin/env ruby
# vim:ts=4:sw=4:et:smartindent:nowrap
require 'erb'
require 'fileutils'

# Define Defaults
$overlayXY = %w(0 fraction 1 fraction 0 fraction 1 fraction -1 fraction -1 fraction)
TemplateOverlayKML = %(<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
  <Document>
    <ScreenOverlay id="<%= name %>-id">
        <name><%= name %></name>
        <Icon><href><%= name %><%= filetype %></href></Icon>
        <overlayXY x="<%= so_xy[0] %>" y="<%= so_xy[2] %>" xunits="<%= so_xy[1] %>" yunits="<%= so_xy[3] %>"/>
        <screenXY x="<%= so_xy[4] %>" y="<%= so_xy[6] %>" xunits="<%= so_xy[5] %>" yunits="<%= so_xy[7] %>"/>
        <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
        <size x="<%= so_xy[8] %>" y="<%= so_xy[10] %>" xunits="<%= so_xy[9] %>" yunits="<%= so_xy[11] %>"/>
    </ScreenOverlay>
  </Document>
</kml>
)

def makeOverlayKML(dir)

    # Collect Images
    images=[]
    images=Dir.glob("#{dir}/**.{jpg,png}")

    # Build KML from template
    images.each do |i|
        renderer = ERB.new TemplateOverlayKML
        filename = File.basename(i)
        filetype = File.extname(filename)
        #name = filename.gsub(' ','-').downcase
        name = File.basename(i,File.extname(i)).gsub(' ','-').downcase
        so_xy = $overlayXY
        kml_file = "#{dir}/#{name}.kml"

        STDOUT.puts "Processing #{name}:"
        STDOUT.print "Building #{name} KML."
        kml = renderer.result(binding)
        File.write(kml_file, kml)
        STDOUT.puts "\s\s\t  OK."
        STDOUT.print "Zipping #{name} KML."
        `zip #{kml_file.chomp('.kml')}.kmz -j #{kml_file} #{i}`
        STDOUT.puts "\s\s\t  OK."
 
    end
end


dir = ARGV[0]
if dir.nil?
    printf "No input dir provided!"
    sleep(1)
    puts " Exiting."
else
    makeOverlayKML(dir)
end

