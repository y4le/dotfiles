#!/bin/bash
SCALE = $
ffmpeg -i $1 -vf scale=${3:-320}:-1 -r 10 -f image2pipe -vcodec ppm - | convert -delay 10 -loop 0 -layers Optimize - $2
