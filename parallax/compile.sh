#!/bin/sh
set -e
ocamlc convmsg.ml -o convmsg
./convmsg > message.s
$PASTA parallax.s -o demo
cp -r demo demo.inf "$OUTPUTDISK"
