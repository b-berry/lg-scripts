#!/usr/bin/env ruby

require 'fileutils'
require 'logger'
require 'nokogiri'
require 'open-uri'
require 'ostruct'
require 'optparse'
require 'pry'
require 'securerandom'
require 'zip'


BackupName = ".backup"
TempDir = ".tmp"
FileType = ["kml","kmz"]
HostROS ="http://localhost" 
PortROS =":8765"
PathROS = "/query.html"
QueryROS = "?query=playtour="

$log = Logger.new('./batchTour.log')
$log.level = Logger::WARN


class Optparse

    def self.parse(args) 

        # Parse Options
        options = OpenStruct.new
        options.autoplay = false
        options.backup = BackupName
        options.dir = './'
        options.encoding = "utf8"
        options.view = []

        opts = OptionParser.new do |opts|
            # Set Defaults here
            opts.banner = "Usage: convertROS.rb [options] -d $PATH"

            opts.separator ""
            opts.separator "Specific options:"

            opts.on("-d", "--asset-dir PATH", 
                "Require asset-dir PATH") do |dir|
                # Test asset-dir PATH
                if Dir.exists?(dir)
                    options.dir = dir
                else
                    STDERR.puts "Specified asset-dir: #{dir}"
                    STDERR.puts "  Does not exist.  Exiting!"
                    exit 1
                end
            end
            
            opts.on("-a", "--autoplay",
                "Run AutoPlay conversion") do |a|
                options.autoplay = true
            end
                
            opts.on("-b", "--backup-dir PATH", 
                "Specify backup-dir PATH") do |dir|
                options.backup = dir
            end
            
            opts.on("-v", "--view initialFOV,targetFOV", Array, 
                "Specify initial,target FOV") do |v|
                # Test input data type
                if v.is_a?(Enumerable)
                    v.each do |fov|
                        unless fov.to_i > 0
                            STDERR.puts "Specified view parameter: #{fov}"
                            STDERR.puts "    not an integer.  Exiting!"
                            exit 1
                        end
                        options.view << fov.to_i
                    end
                else
                    STDERR.puts "Specified view: #{v}:"
                    STDERR.puts "    not an array of inital,target FOV.  Exiting!"
                    exit 1
                end
            end

            opts.on_tail("-h", "--help", "Prints this help") do
                STDOUT.puts opts
                exit
            end
        end

    opts.parse!(args)
    options
  end

end


def collectFiles(path)

    files = {}
    FileType.each do |ext|
        files[ext.to_sym] = Dir.glob("#{path}/**.#{ext}")
        STDOUT.puts "Found #{ext.upcase} in #{path.gsub('/','')}: #{files[ext.to_sym].length}" 
    end
 
    return files 

end


def backupFile(file,options)

    # Test backup abs or rel
    if options.backup[0] == '/'
        dir = options.backup
    else 
        dir = [options.dir,options.backup.gsub('./','')].join('/')
    end

    unless Dir.exists?(dir)
        FileUtils.mkdir_p dir
    end

    # Test dir creation
    unless Dir.exists?(dir)
        STDERR.puts "Could not create specified backup-dir: #{dir}"
        STDERR.puts "  Does not exist.  Exiting!"
        exit 1
    end

    ## Backup file
    FileUtils::cp file, dir

    # Test backup 
    bfile = [dir,File.basename(file)].join('/')
    unless File.exists?(bfile)
        STDERR.puts "Filed to create specified backup-file: #{bfile}"
        STDERR.puts "  Check failed - File does not exist .  Exiting!"
        exit 2
    end

end


def parseFiles(files,options)
    
    files.keys.each do |type|

        STDOUT.puts "Processing #{type}:"

        files[type].each do |file|
            STDOUT.puts " #{file.split('/').last}"
            # Test filetype 
            ftype = `file #{file}`
            case ftype
            when /XML/
                # Open KML file
                doc = File.open(file) { |f| Nokogiri::XML(f) }
                convertFile(doc,file,options)
                writeFile(doc,file)
            when /Zip/
                #zipFile(doc,file)
                FileUtils::mkdir_p "#{options.dir}/#{TempDir}"
                #processKmz(file)
                unzipFile(file,options)
            else
                next
            end
        end 
    end
end


def convertAutoplay(url)

        # Extract Director Url
        href = URI.parse(url.css("href").text)
        host = href.host
        port = href.port
        path = href.path
        query = href.query
	
	# Skip if query missing
	return if query.empty? or query.nil?

        # Extract #{tourname}
        # Set delimiter
        if query.include?('&amp;')
            del = '&amp;'
        else
            del = '&'
        end
        if query.split(del).length > 1
            query.split(del).each do |que|
                playtourTest = que.split('=').index('playtour')
                next if playtourTest.nil?
                @tourname = que.split('=')[playtourTest.to_f + 1]
            end
        else
            playtourTest = query.split('=').index('playtour')
            @tourname = query.split('=')[playtourTest.to_f + 1]
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
        puts "...Modifying Url: #{hrefRosReplace}"
        return hrefRosReplace 

end


def convertFile(doc,file,options)

    networkLink = doc.css("NetworkLink") 
    # Skip file if no NetworkLink present
    return if networkLink.empty?
    # Get networkLink Name
    networkLinkName = networkLink.css("name")
    if networkLinkName.css("name").text  == "Autoplay" then 
        # Backup File to be modified
        backupFile(file,options)
        # Run autoplay convert
        if options.autoplay
            # Build updated URI
            hrefRosReplace = convertAutoplay(networkLink)
            puts "...Modifying Url: #{hrefRosReplace}"
            networkLink.at_css("href").content = hrefRosReplace
        end

        # Run abstractView convert
        unless options.view.empty?
            abstractViews = doc.css("LookAt") 
            # Skip file if no LookAtpresent
            return if abstractViews.empty?
            # Run convertRange method
            abstractViews.each{ |lookat|
                convertRange(lookat,options.view)
            }
        end
    end
    return doc

end


def convertRange(lookat,view)

    # Extract Range
    range = lookat.children.css("range").text.to_f
    # Calculate multiplier
    mod = view[0] / view[1]
    range_i = range * mod
    # Modify range
    unless lookat.children.at_css("range").nil?
        lookat.children.at_css("range").content = range_i
    end

end


def imageResize(file,img,entry)

    # input_image_filename, output_image_filename, max_width, max_height
    #Image.resize(img, img_r, 1215, 2160) 

    img_r = "#{img.gsub('.png','')}-resize.png" 
    puts "...Resizing #{img} -> #{img_r}"
    `convert #{img} -resize x2160 #{img_r}`

    # fix
    `ln -snf "#{File.basename(img_r)}" "#{img}"` 
	
    # Zip image
    zipFile(file, img_r, entry)

end


def writeFile(doc,file)

    # Write modified changes
    #File.write(file, doc.to_xml)
    puts "...Writing modifications: #{file}"
    #File.open(file, 'w') { |f| f.print(doc.to_xml) }
    File.write("#{file}", doc.to_xml)
    puts "...done."

end


def processKmz(file)

    puts "...Attempting Zip Extraction."
    # ZipRuby gem usage
    Zip::Archive.open(file) do |ar|
        i = 0
        ar.each do |f|
            fname = f.name
            if fname.split('.').last == "kml"
                ar.fopen(fname) do |d|
                    doc = Nokogiri::XML(d.read)
                    convertFile(doc)
                    # Replace w/ updated #{doc}
                    #docUpdate = StringIO.open(string="#{doc.text}")
                    #docUpdate = doc.write_to(fname, :encoding => 'UTF-8', :indent => 2)
                    doc_update = doc.serialize
                    doc_replace = StringIO.new
                    doc_replace.write doc_update
                    ar.replace_io(i,doc_replace)
                    #ar.replace_file(fname,docUpdate)
                    #ar.replace_io(fname,doc)
                    ar.commit
                end
            end
        i += 1
        end    
    end


end


def userConfirm(options)

    # Issue warning
    STDOUT.puts "### WARNING!! ###"
    STDOUT.puts "# Running this script will modify asset_files in: #{options.dir}"
    STDOUT.puts "###"

    STDOUT.puts
    STDOUT.printf "Please type 'YES' to continue: " 
    prompt = STDIN.gets.chomp

    exitRun unless prompt == 'YES'

end


def exitRun()

    STDOUT.puts "User Aborted, exiting!"
    exit 0

end


def unzipFile(file,options)

    puts "...Unpacking KMZ: #{file}..."

    zip_entries = []
    # RubyZip gem usage
    d_name = File.basename(file).gsub('.','-').gsub(' ','-')
    t_path = "#{options.dir}/#{TempDir}/#{d_name}"
    Zip::File.open(file).each do |entry|
        fullname = entry.to_s	
        filename = File.basename(fullname) 
        #filename = "#{SecureRandom.urlsafe_base64}" 
        case fullname.split('.').last 
        when 'kml' 

            doc_string =  entry.get_input_stream.read
            doc = Nokogiri::XML(doc_string)

            ## Process KML
            convertFile(doc,file,options)

            ## Test KML
            if doc_string == doc.serialize
                puts "...No change found. Skipping."
                next
            end
            
            zip_entries << { :name => entry, :content => doc.serialize }
        
            ## Write modified doc to disk
            FileUtils.mkdir_p(t_path) unless File.directory?(t_path)
            doc_update = "#{t_path}/#{filename}"
            File.write("#{doc_update}", doc.to_xml)
            zipFile(file, doc_update, fullname)
            #else

            # Read into memory
            #zip_entries << { :name => entry, 
            #                 :content => entry.get_input_stream.read }

#        when 'png'
#    
#            # Extract Image
#            img_string = entry.get_input_stream.read 
#            img_name = "#{$path}/#{TempDir}/#{filename}" 
#            puts "...Extracting from #{file}: #{img_name}"
#            File.write("#{img_name}", img_string)             
#            # Convert Image
#            imageResize(file, img_name, fullname)

	else 
            next
        end

    
        # Find KML entry(s) ** IF solution to `zip -u foo.kmz #{doc}` found
        #entry = zip_file.glob('*.kml').each do |kml|
        #    doc_string =  entry.get_input_stream.read
        #    doc = Nokogiri::XML(doc_string)

            # Process KML
        #    convertFile(doc)
            
            # Update KML
        #    doc_update = doc.serialize
            
        #end

    end 

    #zipFile(file,zip_entries)

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


    #puts "Unpacking KMZ: #{file}..."
    #kmls = `unzip -p -j #{file} doc.kml`

    # Test Unzip
    #if kmls.empty? 
    #     puts "...Unpack failed, no doc.kml found."
    #end
 
    #kmls.each do |k|
        # Open KML file
        #doc = XML::Document.string(kmls) { |f| Nokogiri::XML(f) }
    #    doc = Nokogiri::XML(kmls)

    #    unless doc.nil?
    #        puts "...OK."
    #        convertFile(doc)
        
            # Update file in archive
    #        zipFile(doc,file)
    #    end
    #end

end


def zipFile(file, filename, entry)


    if File.exists?(filename) 

	# Modifiy entry to match in-archive path
	#entry = File.basename(entry)

    #    puts "...Updating: #{file}"
    #    puts "             #{filename} -> #{entry}"
    #    `zip -f #{file} #{entry}`

	Zip::File.open(file) do |zip_update|
	    puts "...Updating: #{file}"
	    puts "             #{filename} -> #{entry}"
	    #zip_update.replace("#{entry}","#{filename}")
            f_ext = "#{File.basename(filename).split('.').last}"
	    temp_n = "#{SecureRandom.urlsafe_base64}.#{f_ext}"
	    zip_update.remove(entry)
	    zip_update.add(temp_n, filename)
	    zip_update.rename(temp_n, entry)
	end
        puts "...OK."

    else
        puts "...ERROR! File not found: #{filename}" 
        puts "   Failed to update: #{file}"
        puts "      Archived file: #{entry}"
    end

    # Update doc.kml in zip archive
    #`zip -u #{file} -j #{doc}`

#    Zip::File.open(file, Zip::File::CREATE) do |zipfile|
#        zip_entries.each do |zipper|
            # Two arguments:
            # - The name of the file as it will appear in the archive
            # - The original file, including the path to find it
#            zipfile.get_output_stream(zipper.fetch(:name)) { |os| os.write "#{zipper.fetch(:content).to_s}" }
#            zipfile.add(file, zipper.fetch(:name) )
#        end
#    end

end


### Run Time Operations Start Here ###

options = Optparse.parse(ARGV)
STDOUT.puts options
files = collectFiles(options.dir)

# Get user permision to run conversion
userConfirm(options)

# Process files
parseFiles(files,options)
