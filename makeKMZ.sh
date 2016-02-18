#!/usr/bin/env bash

replaceme="REPLACEME"
template="doc.kml"

doc_ext=".kml"
zip_ext=".kmz"

asset_dir="$1"

if [[ -z "$1" ]]; then
    echo "ERROR: No asset path provided."
    exit
fi

img_ext=".png"

echo "Wrapping PNG to KML..."
echo "...search performed: find $(echo "${} -iname *${img_ext}")"

while read -r LINE; do

    # Gather vars
    name="${LINE%.png}"
    docname=`basename "${name}"`
    imgname=`basename "${LINE}"`
    filename="${name}-overlay.kml"
    zipname="${name}-overlay.kmz"

    # Run opts
    echo "${filename}:"
    cp -vf "${template}" "${filename}" || exit 1
    # Replace name
    sed -i -e "s:${replaceme}:${docname}:g" "${filename}"
    echo "...${filename} complete"

    # Create Zip Archive
    echo "...Zipping KML to KMZ..."    
    echo "Creating ${zipname} from:"
    echo "	${filename}"
    echo "	 ${imgname}"
    zip "${LINE%.png}-overlay.kmz" -j "${LINE%.png}-overlay.kml" "${LINE}"
    echo "...done."
done < <(find $(echo "${asset_dir} -iname *${img_ext}"))   

img_ext=".jpg"

echo "Wrapping JPG to KML..."
echo "...search performed: find $(echo "${} -iname *${img_ext}")"

while read -r LINE; do

    # Gather vars
    name="${LINE%.jpg}"
    docname=`basename "${name}"`
    imgname=`basename "${LINE}"`
    filename="${name}-overlay.kml"
    zipname="${name}-overlay.kmz"

    # Run opts
    echo "${filename}:"
    cp -vf "${template}" "${filename}" || exit 1
    # Replace name
    sed -i -e "s:${replaceme}:${docname}:g" "${filename}"
    echo "...${filename} complete"

    # Create Zip Archive
    echo "...Zipping KML to KMZ..."    
    echo "Creating ${zipname} from:"
    echo "	${filename}"
    echo "	 ${imgname}"
    zip "${LINE%.jpg}-overlay.kmz" -j "${LINE%.jpg}-overlay.kml" "${LINE}"
    echo "...done."
done < <(find $(echo "${asset_dir} -iname *${img_ext}"))   

echo "Complete!"
