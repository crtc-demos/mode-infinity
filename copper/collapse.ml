let extract num =
  let b7 = num land 128
  and b5 = num land 32
  and b3 = num land 8
  and b1 = num land 2 in
  Printf.printf "%d %d %d %d\n"
    (if b7 <> 0 then 1 else 0)
    (if b5 <> 0 then 1 else 0)
    (if b3 <> 0 then 1 else 0)
    (if b1 <> 0 then 1 else 0)

let recode num =
  ((num land 128) lsr 4)
  lor ((num land 32) lsr 3)
  lor ((num land 8) lsr 2)
  lor ((num land 2) lsr 1)

let letter n = "ABCDEFGHIJKLMNOP".[n]

let collapse num =
  let nref = ref num in
  for i = 0 to 7 do
    extract !nref;
    nref := (!nref lsl 1) lor 1
  done

let collapse_to_letters num =
  let nref = ref num in
  let buf = Buffer.create 5 in
  for i = 0 to 7 do
    let recoded = recode !nref in
    Buffer.add_char buf (letter recoded);
    nref := (!nref lsl 1) lor 1
  done;
  Buffer.contents buf
  
(*let toprows =    [0b00011100; 0b01110001; 0b11000111]
let bottomrows = [0b11100011; 0b10001110; 0b00111000]*)

(*let toprows =    [0b01010101; 0b01010101; 0b01010101]
let bottomrows = [0b10101010; 0b10101010; 0b10101010]*)

let toprows =    [0x6d; 0xb6; 0xdb]
let bottomrows = [0xb6; 0xdb; 0x6d]

(*let toprows = [0b01011101; 0b01011101; 0b01011101]
let bottomrows = [0b10101010; 0b10101010; 0b10101010]*)

(*let toprows = [0x5d; 0x5d; 0x5d]
let bottomrows = [0x55; 0x55; 0x55]*)

let subst str f r =
  let str' = String.copy str in
  for i = 0 to String.length str' - 1 do
    if str'.[i] = f then
      str'.[i] <- r
  done;
  str'

let subst_list str fset r =
  List.fold_right (fun letter str -> subst str letter r) fset str

let count str letter =
  let cnt = ref 0 in
  String.iter (fun thischar -> if thischar = letter then incr cnt) str;
  !cnt

let listcount strlist letter =
  List.fold_right (fun str acc -> acc + count str letter) strlist 0

let starify str star =
  let out = String.make (String.length str) ' ' in
  for i = 0 to String.length out - 1 do
    if String.contains star str.[i] then
      out.[i] <- '*'
  done;
  out

let draw strlist star =
  let s = Array.map
    (fun str -> starify str star)
    (Array.of_list strlist) in
  let num = Array.fold_right (fun item acc -> acc + count item '*') s 0 in
  Printf.printf "Number of stars: %d/48\n" num;
  for i = 0 to 2 do
    Printf.printf "%s%s%s%s%s%s%s%s%s\n"
      s.(0) s.(1) s.(2) s.(0) s.(1) s.(2) s.(0) s.(1) s.(2);
    Printf.printf "%s%s%s%s%s%s%s%s%s\n"
      s.(3) s.(4) s.(5) s.(3) s.(4) s.(5) s.(3) s.(4) s.(5)
  done

let x = List.map collapse_to_letters (toprows @ bottomrows)
