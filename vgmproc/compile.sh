#!/bin/sh
set -e
ocamlc vgmproc.ml -o vgmproc
./vgmproc ice.vgm ice.s
pasta ice.s -o ice
pasta player.s -o player
pasta ptest.s -o ptest
cp player player.inf ice ice.inf "$OUTPUTDISK"
