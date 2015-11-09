#!/bin/bash

# Remove '#' && '.'  && ' ' from directories && files
find ./ -exec rename -f 's/#//' {} +
find ./ -exec rename -f 's/.//' {} +
find ./ -iname "* *" -exec rename -f 's/\ /_/' {} +
# Downcase directories
find ./ -type d -exec rename -f 's/A-Z/a-z/' {} +
