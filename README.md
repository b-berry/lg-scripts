## lg-scripts
Content Development Automation for the Liquid Galaxy platform

RUBY VERSION:
1.9.3-p194
 
GEM LIST:

bigdecimal (1.1.0)
bundler (1.10.6)
io-console (0.3)
json (1.5.4)
kamelopard (0.0.15)
libxml-ruby (2.8.0)
mini_portile (0.6.2)
minitest (2.5.1)
nokogiri (1.6.6.2)
rake (0.9.2.2)
rdoc (3.9.4)
xml-simple (1.1.5)

HELP MENU:

```
Usage: example.rb [options] -A {director,ispaces,roscoe} FILE
    -h, --help                       Prints this help
    -a, --autoplay TYPE              Build AutoPlay query using TYPE
                                      (["director", "ispaces", "roscoe"])
    -f, --flight TYPE                Build flight dynamics using TYPE
                                      (["flyto", "orbit", "spline"])
    -g, --graphic TYPE               Build graphics using TYPE
                                      (["box", "screenOverlay"])
    -m, --migrate [to ROS] PATH
    -o, --override h,r,t             Override abstract view: heading,tilt,range
    -r, --regions                    Build tour w/ Regions
    -s, --screenOverlay PATH
    -w, --write-each                 Build [flyto, orbit] tour for each placemark
```

EXAMPLES:

## Build screen Overlays from $images/*
./batchTour.rb -s images/

## Build flyTo tours for each placemark in placemarks.kml
./batchTour.rb -a roscoe -f flyto -w placemarks.kml

## Build orbit tours w/ abstractView override from placemarks.kml
./batchTour.rb -a roscoe -f orbit -o 0,1000,57 -w placemarks.kml

