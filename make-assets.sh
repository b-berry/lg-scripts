#!/bin/bash

HELP="
Usage: ${0} [-d|--dir DIR -a|--all -h|--help] ZIPFILE

Options: 
    [-d|--dir]
        Specify directory to extract asset_files into
            default = \"asset_files/\"
    [-a|--all]
        Specify extraction from all zip files in .
             use this opt as last ARG
    [-h|--help]
        Display this message

"

# Handle ARGs
while true; do
  case "$1" in
    -h|--help) echo "${HELP}" ; shift 
         exit 0
         ;;
    "")  echo "${HELP}" ; shift
         exit 1
         ;;
    -a|--all) ASSET_ARCHIVE="*.zip"
         shift 2
         break
         ;;
    -d|--dir) ASSET_DIR="$2"
         shift 2
         ;;
    --) shift ; break 
         ;;
    *) ASSET_ARCHIVE="$1"
         if [ -f ${ASSET_ARCHIVE} ]; then
           break
         else
           echo "ERROR: ${ASSET_ARCHIVE} doesn't exist."
           exit 1
         fi
         shift 2
         ;;
  esac
done
 
# Set Vars
if [[ -z "${ASSET_DIR}" ]]; then
  ASSET_DIR="asset_files"
fi

echo "Asset Dir: ${ASSET_DIR}"
echo "Asset Arch: ${ASSET_ARCHIVE}"
#exit

# Unzip archive(s)
mkdir -p "${ASSET_DIR}" &&\
while read -r FILE; do
  unzip -d "${ASSET_DIR}" -u "${FILE}"  
done< <(find ./ -iname "${ASSET_ARCHIVE}") || exit 2

# Begin filename correction(s)
while read -r FILE; do

  # Build rename string
  if [[ -n "${FILE}" ]]; then
    filename="$(echo "${FILE}" | \
      sed -e 's:\ :_:g' | \
      sed -e 's:[()]::g' | \
      sed -e 's:_-_:_:g' | \
      sed -e 's:_-:-:g' | \
      sed -e 's:-_:-:g' | \
      sed -e 's:__:_:g' | \
      sed -e 's:\(.*\):\L\1:' )" && \
    dirname="$(dirname "${filename}")" && \

    # Test string manipulation
    if [[ -n "${dirname}" ]]  && [[ -n "${filename}" ]]; then
      echo "${dirname}:"
      echo "${FILE} -> ${filename}" 
      mkdir -p "${dirname}" && \
      mv -uvf "${FILE}" "${filename}"
    fi
  fi 

  # Test modified filename file exists && remove old
  if [ -f $filename ]; then
    rm -rvf "${FILE}"
  fi

  unset FILE
  unset filename

done< <(find "${ASSET_DIR}" -type f)

# Cleanup
find ${ASSET_DIR} -type d -empty -delete
