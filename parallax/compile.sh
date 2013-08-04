#!/bin/sh
set -e
$PASTA parallax.s -o parallx
cp -r parallx parallx.inf "$OUTPUTDISK"
