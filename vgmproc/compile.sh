#!/bin/sh
set -e
ocamlc vgmproc.ml -o vgmproc
./vgmproc ice.vgm ice.s
pasta player.s -o player
cp player player.inf "$OUTPUTDISK"
