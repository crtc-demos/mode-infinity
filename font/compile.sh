ocamlfind ocamlc -g -package camlimages.all_formats -linkpkg fontconv.ml -o fontconv
./convert.sh
# cp font font.inf "$OUTPUTDISK"
