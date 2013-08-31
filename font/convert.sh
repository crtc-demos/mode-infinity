#!/bin/sh
set -e
./fontconv -o font.s 16x16.png
pasta font.s -o font
