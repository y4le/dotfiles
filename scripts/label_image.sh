#!/bin/bash

convert $1 -fill white -undercolor '#000000080' -gravity South -pointsize 70 -annotate +0+5 $3 $2
