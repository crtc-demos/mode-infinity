#!/bin/sh
set -e
$PASTA copper.s -o copper
COPPERSIZE=$(wc -c copper | awk '{print $1}')
cat > copper-size.s << EOF
	.alias copper_size $COPPERSIZE
EOF
cp -r copper copper.inf "$OUTPUTDISK"
