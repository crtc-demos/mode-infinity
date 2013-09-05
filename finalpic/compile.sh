#!/bin/sh
set -e
ocamlc unix.cma rle.ml -o rle
./rle owl3 owl3z
OWLSIZE=$(wc -c owl3z | awk '{print $1}')
cat > final-pic-size.s << EOF
	.alias final_pic_size $OWLSIZE
EOF
# pasta unrle.s -o unrle
cp owl3z owl3z.inf "$OUTPUTDISK"
