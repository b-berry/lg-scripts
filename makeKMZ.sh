#!/usr/bin/env bash

path="./"
img_ext=".png"
replaceme="REPLACEME"
template="doc.kml"

doc_ext=".kml"
zip_ext=".kmz"

echo "Wrapping PNG to KML..."
while read -r LINE; do

    # Gather vars
    name="${LINE%.png}"
    docname=`basename "${name}"`
    imgname=`basename "${LINE}"`
    filename="${name}.kml"
    zipname="${name}.kmz"

    # Run opts
    echo "${filename}:"
    cp -vf "${template}" "${filename}" || exit 1
    # Replace name
    sed -i -e "s:${replaceme}:${docname}:g" "${LINE%.png}.kml"
    echo "...${filename} complete"

    # Create Zip Archive
    echo "...Zipping KML to KMZ..."    
    echo "Creating ${zipname} from:"
    echo "	${filename}"
    echo "	 ${imgname}"
    zip "${LINE%.png}.kmz" "${LINE%.png}.kml" "${LINE}"
    echo "...done."
done < <(find ../ -iname *.png)   

echo "Complete!"
     
