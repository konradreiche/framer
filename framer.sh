#!/bin/bash

# get absolute geometry of currently focused window
RECT=$(swaymsg -t get_tree | jq -r '.. | select(.focused?) | .rect')

# parse coordinates and dimensions
COORDINATES=$(jq -r '"\(.x),\(.y)"' <<< $RECT)
DIMENSIONS=$(jq -r '"\(.width)x\(.height)"' <<< $RECT)
WIDTH=$(jq .width <<< $RECT)
HEIGHT=$(jq .height <<< $RECT)

# use temporary directory to process files
TMP_DIR=$(mktemp -d)

# create screenshot
grim -g "$COORDINATES ${WIDTH}x${HEIGHT}" $TMP_DIR/screenshot.png

# read width and height from screenshot to account for scaling
WIDTH=$(magick identify -format "%w" $TMP_DIR/screenshot.png)
HEIGHT=$(magick identify -format "%h" $TMP_DIR/screenshot.png)

# generate rounded corners mask
magick -size ${WIDTH}x${HEIGHT} xc:none -draw "roundrectangle 0,0,$WIDTH,$HEIGHT,10,10" $TMP_DIR/mask.png
magick $TMP_DIR/screenshot.png -alpha Set $TMP_DIR/mask.png -compose DstIn -composite $TMP_DIR/screenshot.png

# add drop shadow effect
SHADOW_OFFSET=+2+2
magick $TMP_DIR/screenshot.png \( +clone -background black -shadow 75x3${SHADOW_OFFSET} \) +swap -background none -layers merge +repage $TMP_DIR/screenshot.png

# look up current background image
BACKGROUND_IMAGE=$(swaymsg -t get_config | jq -r .config | grep bg | cut -d' ' -f4)

# expand tilde to home directory
BACKGROUND_IMAGE=${BACKGROUND_IMAGE/#\~/$HOME}

# crop background image to size of screenshot with 10% border
MIN=$(( $WIDTH > $HEIGHT ? $HEIGHT : $WIDTH ))
BORDER=$(awk "BEGIN { printf(\"%.0f\n\", $MIN * 0.1); }")
RESIZE=$((WIDTH + BORDER))x$((HEIGHT + BORDER))!
magick $BACKGROUND_IMAGE -gravity Center -resize $RESIZE $TMP_DIR/background.png

# compose screenshot over background
magick $TMP_DIR/background.png $TMP_DIR/screenshot.png -gravity Center -geometry ${SHADOW_OFFSET} -compose Over -composite ~/screenshot-$(date +%s).png

# delete temporary directory
rm -r $TMP_DIR
