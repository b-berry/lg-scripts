#!/bin/bash

LOGFILE="testUSB.log"
LOGPATH="/home/lg/tmp"
LOG="${LOGPATH}/${LOGFILE}"
NAV="spacenavigator"
NAVC=0
TOUCH="lg_active_touch"
TOUCHC=0
DEVPATH="/dev/input"
DUR="$(echo "60*10" | bc)"

echo "Running device test for $(echo "${DUR}/60" | bc) minutes:"
echo "...Clearing logfile: ${LOG}"
echo -n '' > $LOG

n=0

# Test Nav Connection
if [ -e "${DEVPATH}/${NAV}" ]; then
  echo "...${NAV} Exists, runing test"
else 
  echo "...${NAV} Not Found, exiting!"
  exit 1
fi

# Test Touch Connection
if [ -e "${DEVPATH}/${TOUCH}" ]; then
  echo "...${TOUCH} Exists, runing test"
else 
  echo "...${TOUCH} Not Found, exiting!"
  exit 1
fi

# Run tests
while [ $n -lt $DUR ]; do 
	if [ ! -e "${DEVPATH}/${NAV}" ]; then
		echo "`date +%Y%m%d+%T` - No Spacenavigator Detected!" >> $LOG
		NAVC=$(echo "${NAVC}+1" | bc)
	fi

	if [ ! -e "${DEVPATH}/${TOUCH}" ]; then
		echo "`date +%Y%m%d+%T` - No Touchscreen Detected!" >> $LOG
		TOUCHC=$(echo "${TOUCHC}+1" | bc)
	fi
	sleep 1
	n=$(echo "${n}+1" | bc)
done

# Report Results
echo "=============================="
echo "Spacenavigator Faults: ${NAVC}"
echo "Touchscreen Faults: ${TOUCHC}"
echo "=============================="
