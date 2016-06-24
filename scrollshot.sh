#!/bin/bash

# The MIT License (MIT)

# Copyright (c) 2015 Eric Leong
# https://github.com/ericleong/scrollshot

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Filename
if [ "$1" = "" ] ; then
    FILENAME="scrollshot"
else
    FILENAME=$1
fi

# Number of times to run
if [ "$2" = "" ] ; then
    COUNT=3
else
    COUNT=$2
fi

# Height of footer to keep (in pixels)
if [ "$3" != "" ] ; then
    FOOTER_KEEP=$3
fi

# Height of footer to ignore (in pixels)
if [ "$4" != "" ] ; then
    FOOTER_IGNORE=$4
else
    FOOTER_IGNORE=0
fi

# Try to get density with "wm"
if ! DENSITY=$(adb shell wm density) ; then
    exit
fi


if [[ $DENSITY == *"wm: not found"* ]] ; then
    # Grab density with "getprop"
    DENSITY=$(adb shell getprop | grep density)
fi

# Grab actual density value
DENSITY=$(echo $DENSITY | grep -o "[0-9]\+")

# Initial offset to test 
if [ "$6" = "" ] ; then
    OVERLAP_OFFSET_START=-$(expr $DENSITY \* 4 \/ 160) # 4 dp
else
    OVERLAP_OFFSET_START=$6
fi

# Overlap test height 
if [ "$7" = "" ] ; then
    OVERLAP_TEST_HEIGHT=$(expr $DENSITY \* 20 \/ 160) # 20 dp
else
    OVERLAP_TEST_HEIGHT=$7
fi

# Final offset to test 
if [ "$8" = "" ] ; then
    OVERLAP_OFFSET_END=$(expr $DENSITY \* 4 \/ 160) # 4 dp
else
    OVERLAP_OFFSET_END=$8
fi

# Set some overlap test variables
OVERLAP_TEST_THRESHOLD="0.01" # 1% root mean squared difference (standard deviation)

# Get version number
VERSION=$(adb shell getprop ro.build.version.release)
MAJOR_VERSION=$(echo $VERSION | cut -c 1)
MINOR_VERSION=$(echo $VERSION | cut -c 3)
# Test if integer, then test if >= 5.0 (Lollipop)
if [[ "$MAJOR_VERSION" =~ ^-?[0-9]+$ ]] ; then
    if [ "$MAJOR_VERSION" -ge "5" ] ; then
        if [ "$(adb shell dumpsys power | grep mWakefulness=Asleep)" != "" ] ; then
            # Wake the device if necessary
            adb shell input keyevent 26

            # Unlocks the screen
            adb shell input keyevent 82
        fi
    elif [ "$(adb shell dumpsys power | grep mUserActivityAllowed=true)" == "" ] ; then
        # Wake the device if necessary
        adb shell input keyevent 26

        echo "Device is locked."

        exit 1
    fi
fi

# Sleep, just in case.
sleep 1

# Grab orientation
ORIENTATION=$(adb shell dumpsys input | grep "SurfaceOrientation" | awk '{ print $2 }' | tr -d "\r")
ROTATION=$(expr ${ORIENTATION} \* -90)

# Screenshot!
adb shell screencap -p | sed "s|\r$||" > ${FILENAME}.png 2>/dev/null

if [ $? -ne 0 ] ; then
    # Probably OS X, assume we can use perl
    adb shell screencap -p | perl -pe "s/\x0D\x0A/\x0A/g" > ${FILENAME}.png

    # Flag that we need to use OS X-compliant commands
    OSX=1
else
    OSX=0
fi

# Rotate!
if [ $ROTATION -ne 0 ] ; then
    convert ${FILENAME}.png -rotate $ROTATION ${FILENAME}.png
fi

# Grab image width + height
WIDTH=$(identify -format "%w" $FILENAME.png)
HEIGHT=$(identify -format "%h" $FILENAME.png)

# Vertical pixels to swipe
if [ "$5" = "" ] ; then
    VERTICAL=$(expr $DENSITY \* 2)

    if [ $VERTICAL -gt $(expr $HEIGHT \/ 2) ] ; then
        VERTICAL=$DENSITY
    fi
else
    VERTICAL=$5
fi

# Collect data for $COUNT times
for i in `seq -s " " 1 $COUNT`; do

    # Scroll
    if [[ "$MAJOR_VERSION" =~ ^-?[0-9]+$ ]] ; then
        if [ "$MAJOR_VERSION" -ge "5" ] ; then
            adb shell "input touchscreen swipe 100 $VERTICAL 100 0 2000"
        elif [ "$MAJOR_VERSION" -ge "4" ] && [ "$MINOR_VERSION" -gt "1" ] ; then
            adb shell "input touchscreen swipe 100 $VERTICAL 100 0 2000" # Same as above
        else
            adb shell "input swipe 100 $VERTICAL 100 0"
        fi
    else
        # Assume new version.
        adb shell "input touchscreen swipe 100 $VERTICAL 100 0 2000"
    fi

    # Sleep, so that the scrollbar disappears.
    sleep 1

    # Screenshot!
    if [ $OSX -eq 0 ] ; then
        adb shell screencap -p | sed "s|\r$||" > ${FILENAME}_scroll.png
    else
        adb shell screencap -p | perl -pe "s/\x0D\x0A/\x0A/g" > ${FILENAME}_scroll.png
    fi

    # Rotate!
    if [ $ROTATION -ne 0 ] ; then
        convert ${FILENAME}_scroll.png -rotate $ROTATION ${FILENAME}_scroll.png
    fi

    if [ $i -eq 1 ] ; then

        if [ "$FOOTER_KEEP" = "" ] ; then
            # Subtract the two screenshots
            composite -compose difference ${FILENAME}.png ${FILENAME}_scroll.png ${FILENAME}_subtract.png

            # Determine the area bottom pixels that are the same
            OVERLAP=$(convert ${FILENAME}_subtract.png -background white -splice 0x1 -background black -splice 0x2 -fuzz 1% -trim +repage -chop 0x1 info:- | cut -d " " -f 3 | cut -d "x" -f 2)

            FOOTER_KEEP=$(expr $HEIGHT \- $OVERLAP)

            if [ $FOOTER_KEEP -le 0 ] ; then
                # In case of failure and in portrait
                if [ $ROTATION -eq 0 ] || [ $ROTATION -eq 2 ] ; then
                    
                    # Check if there is a navigation bar
                    NAV_BAR=$(adb shell dumpsys SurfaceFlinger | grep "| NavigationBar")

                    if [ "$NAV_BAR" == "" ] ; then
                        FOOTER_KEEP=0
                    elif [ $OSX -eq 0 ] ; then
                        # Grab the height of the navigation bar
                        FOOTER_KEEP=$(echo $NAV_BAR | cut -d "," -f 4 | cut -d "|" -f 1 | grep -o "[0-9]+\." | cut -d "." -f 1)
                    else
                        FOOTER_KEEP=$(echo $NAV_BAR | cut -d "," -f 4 | cut -d "|" -f 1 | cut -d "." -f1 | tr -d " ")
                    fi
                else 
                    FOOTER_KEEP=0
                fi
            elif [ $FOOTER_KEEP -le $(expr $DENSITY \* 48 \/ 160 \+ $DENSITY \* 8 \/ 160) ] && [ $FOOTER_KEEP -gt $(expr $DENSITY \* 48 \/ 160 \- $DENSITY \* 8 \/ 160) ] ; then
                # If it's really close to the height of the navigation bar (+/- 8dp)
                # Make it the height of th navigation bar
                FOOTER_KEEP=$(expr $DENSITY \* 48 \/ 160)
            elif [ ${FOOTER_KEEP} -gt 0 ] ; then
                FOOTER_KEEP=$(expr $FOOTER_KEEP \+ 1)
            else
                FOOTER_KEEP=0
            fi
        fi

        if [ ${FOOTER_KEEP} -gt 0 ] || [ ${FOOTER_IGNORE} -gt 0 ] ; then
            # Crop bottom part, ignore the part we're supposed to ignore
            convert ${FILENAME}.png -gravity South -crop ${WIDTH}x${FOOTER_KEEP}+0+0 ${FILENAME}_bottom.png

            # Crop first screenshot
            convert ${FILENAME}.png -gravity South -crop 100%x+0+$(expr $FOOTER_KEEP \+ $FOOTER_IGNORE) ${FILENAME}.png
        fi
    fi

    # Crop overlap test area from main screenshot
    convert ${FILENAME}.png -gravity South -crop ${WIDTH}x${OVERLAP_TEST_HEIGHT}+0+0 ${FILENAME}_test.png

    # Test for overlap

    RMSE_MIN=-1
    OFFSET_BEST=0

    for OFFSET in `seq -s " " $OVERLAP_OFFSET_START $OVERLAP_OFFSET_END`; do 

        # Crop test area
        convert ${FILENAME}_scroll.png -gravity South -crop ${WIDTH}x${OVERLAP_TEST_HEIGHT}+0+$(expr $FOOTER_KEEP \+ $FOOTER_IGNORE \+ $VERTICAL \- $OFFSET) ${FILENAME}_scroll_test.png

        # Set to default in case of failure
        RMSE=-1

        RMSE_RAW=$(compare -metric RMSE ${FILENAME}_test.png ${FILENAME}_scroll_test.png NULL: 2>&1)

        # Compare percentage difference with root mean square error metric (standard deviation)
        if [ $OSX -eq 0 ] ; then
            RMSE=$(echo $RMSE_RAW | grep -oP "(?<=\()[0-9.]+(?=\))")
        else
            RMSE=$(echo $RMSE_RAW | grep -oE "\([0-9.]*?\)" | sed "s/[()]//g")
        fi

        if [ "$RMSE" = "" ] ; then
            # Tiny number in scientific notation
            RMSE=$(echo $RMSE_RAW | grep -o "\([0-9.]*e-[0-9]*\)")

            # If it is a tiny number, round to zero
            if [ "$RMSE" != "" ] ; then
                RMSE=0
            else
                RMSE=-1
            fi
        fi

        # Make sure difference is under threshold and store the lowest difference
        if [[ "1" -eq "$(echo "${RMSE} >= 0" | bc)" && "1" -eq "$(echo "${RMSE} < ${OVERLAP_TEST_THRESHOLD}" | bc)" && ( "1" -eq $(echo "${RMSE_MIN} < 0" | bc) || "1" -eq "$(echo "${RMSE} < ${RMSE_MIN}" | bc)" ) ]] ; then
            RMSE_MIN=$RMSE
            OFFSET_BEST=$OFFSET
        fi

    done;

    # Crop
    convert ${FILENAME}_scroll.png -gravity South -crop ${WIDTH}x$(expr $VERTICAL \- $OFFSET_BEST)+0+$(expr $FOOTER_KEEP \+ $FOOTER_IGNORE) ${FILENAME}_scroll.png

    # Append
    convert ${FILENAME}.png ${FILENAME}_scroll.png -append ${FILENAME}.png

done;

if [ ${FOOTER_KEEP} -gt 0 ] ; then
    # Append bottom
    convert ${FILENAME}.png ${FILENAME}_bottom.png -append ${FILENAME}.png
fi

# Scrolling
rm -f ${FILENAME}_bottom.png
rm -f ${FILENAME}_subtract.png
rm -f ${FILENAME}_scroll.png

# Overlap test
rm -f ${FILENAME}_test.png
rm -f ${FILENAME}_scroll_test.png
