#!/bin/sh
set -e
pasta copper.s -o copper
cp -r copper copper.inf "$OUTPUTDISK"
