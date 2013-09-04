#!/bin/sh
set -e
ocamlc convmsg.ml -o convmsg
./convmsg > message.s
$PASTA parallax.s -o parallx
cp -r parallx parallx.inf "$OUTPUTDISK"
