#!/bin/sh
set -e
$PASTA copper.s -o copper
cp -r copper copper.inf "$OUTPUTDISK"
