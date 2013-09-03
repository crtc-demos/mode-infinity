let remap idx =
  let char_row = (idx / 8) mod 32
  and col = idx / 256 in
  char_row * 640 + col * 8 + idx mod 8

let getpixel buf x y =
  let char_row = y / 8
  and pixel_row = y mod 8
  and char_col = x / 4
  and pixel_pos = x mod 4 in
  let byte = Char.code buf.[char_row * 640 + pixel_row + char_col * 8] in
  let cc = match pixel_pos with
    0 -> (byte land 1) lor ((byte land 16) lsr 3)
  | 1 -> ((byte land 2) lsr 1) lor ((byte land 32) lsr 4)
  | 2 -> ((byte land 4) lsr 2) lor ((byte land 64) lsr 5)
  | 3 -> ((byte land 8) lsr 3) lor ((byte land 128) lsr 6)
  | _ -> failwith "unreachable" in
  Char.chr cc

(*

We have:
 3 ABEF
 2 89CD
 1 2367
 0 0145

   0123

We want:
 3 9876
 2 AB45
 1 DC32
 0 EF01

   0123

X,Y			    ~X>>1 ,EOR X
00,00  ->  2,0  ->  10,00   11    11
01,00  ->  3,0  ->  11,00   11    10
10,00  ->  3,1  ->  11,01   10    00
11,00  ->  2,1  ->  10,01   10    01
00,01  ->  2,2  ->  10,10   11    11
01,01  ->  3,2  ->  11,10   11    10
10,01  ->  3,3  ->  11,11   10    00
11,01  ->  2,3  ->  10,11   10    01
00,10  ->  1,3  ->  01,11   11    11
01,10  ->  0,3  ->  00,11   11    10
10,10  ->  0,2  ->  00,10   10    00
11,10  ->  1,2  ->  01,10   10    01
00,11  ->  1,1  ->  01,01   11    11
01,11  ->  0,1  ->  00,01   11    10
10,11  ->  0,0  ->  00,00   10    00
11,11  ->  1,0  ->  01,00   10    01

*)

let getpixel_swiz buf idx mask =
  let blockbits = idx land 0xfff
  and whichblock = idx lsr 12 in
  let x = (blockbits land 1) lor
          ((blockbits land 4) lsr 1) lor
	  ((blockbits land 16) lsr 2) lor
	  ((blockbits land 64) lsr 3) lor
	  ((blockbits land 256) lsr 4) lor
	  ((blockbits land 1024) lsr 5)
  and y = ((blockbits land 2) lsr 1) lor
	  ((blockbits land 8) lsr 2) lor
	  ((blockbits land 32) lsr 3) lor
	  ((blockbits land 128) lsr 4) lor
	  ((blockbits land 512) lsr 5) lor
	  ((blockbits land 2048) lsr 6) in
  let xblk = (whichblock mod 5) * 64
  and yblk = (whichblock / 5) * 64 in
  let cc = getpixel buf (xblk + x) (yblk + y) in
  Char.chr ((Char.code cc) land mask)

let rot n x y rx ry =
  if ry = 0 then begin
    if rx = 1 then n - 1 - y, n - 1 - x else y, x
  end else
    x, y

let getpixel_d2xy buf n d mask =
  let t = ref (d land 0xfff) in
  let x = ref 0
  and y = ref 0
  and rx = ref 0
  and ry = ref 0
  and s = ref 1 in
  while !s < n do
    rx := 1 land (!t / 2);
    ry := 1 land (!t lxor !rx);
    let x', y' = rot !s !x !y !rx !ry in
    x := x' + !s * !rx;
    y := y' + !s * !ry;
    t := !t / 4;
    s := !s * 2
  done;
  let whichblock = d lsr 12 in
  let xblk = (whichblock mod 5) * 64
  and yblk = (whichblock / 5) * 64 in
  let cc = getpixel buf (xblk + !x) (yblk + !y) in
  Char.chr ((Char.code cc) land mask)

let rle buf maxlength mask =
  let rec count idx byteval num =
    if idx < maxlength then begin
      if (getpixel_d2xy buf 64 idx mask) = byteval && num < 141 then
	count (idx + 1) byteval (num + 1)
      else
	(num, byteval) :: count (idx + 1) (getpixel_d2xy buf 64 idx mask) 1
    end else
      [num, byteval] in
  count 1 buf.[remap 0] 1

type classify =
    RLE of int * char
  | Block of int list

(*let eorify buf =
  let accum = ref (Char.code buf.[remap 0]) in
  for i = 1 to String.length buf - 1 do
    let idx = remap i in
    let newbyte = Char.code buf.[idx] in
    let modify = (newbyte - !accum) land 255 in
    buf.[idx] <- Char.chr modify;
    accum := modify
  done*)

let compact nblist blockmax =
  let rec scan block acc = function
    [] ->
      if List.length block > 0 then
        (Block block :: acc)
      else
        acc
  (*| (1, byteval) :: rest ->
      if List.length block + 1 < blockmax then
        scan (byteval :: block) acc rest
      else
        scan [byteval] (Block block :: acc) rest
  | (2, byteval) :: rest ->
      if List.length block + 2 < blockmax then
        scan (byteval :: byteval :: block) acc rest
      else
        scan [byteval; byteval] (Block block :: acc) rest*)
  | (num, byteval) :: rest ->
      if List.length block > 0 then
        scan [] (RLE (num, byteval) :: Block block :: acc) rest
      else
        scan [] (RLE (num, byteval) :: acc) rest in
  scan [] [] nblist

(* Lengths n:
   n < 126: run of length n+16.
   n = 127: run of length 141, followed by more of the same colour.
   n >= 128: block of size n - 128 nybbles follows.
*)

let compact2 nblist =
  let rec scan block acc = function
    [] ->
      if List.length block > 0 then
        Block block :: acc
      else
        acc
  | (num, byteval) :: rest when num <= 16 && List.length block < 128 ->
      scan (num :: block) acc rest
  | (num, byteval) :: rest ->
      if List.length block > 0 then
	scan [] (RLE (num, byteval) :: Block block :: acc) rest
      else
        scan [] (RLE (num, byteval) :: acc) rest in
  scan [] [] nblist

let rec runbits n =
  if n < 4 then
    2
  else if n < 15 then
    6
  else if n < 255 then
    14
  else
    failwith "Unreachable"

let oplength clist =
  List.fold_right
    (fun item count ->
      match item with
        RLE (num, _) -> count + 1
      | Block n -> count + 1 + ((List.length n) + 1) / 2)
    clist
    0

let write clist =
  List.iter
    (function
      RLE (num, byteval) -> Printf.printf "%d x '%d'\n" num (Char.code byteval)
    | Block blk ->
	Printf.printf "blk (%d): %s\n" (List.length blk) (String.concat ","
	  (List.map string_of_int blk)))
    clist

let encode_output rle =
  let oplength = List.length rle * 2 in
  let outstring = String.create oplength in
  let arr = Array.of_list rle in
  for i = 0 to Array.length arr - 1 do
    let length, byte = arr.(i) in
    let length = if length = 256 then 0 else length in
    Printf.printf "len: %d  byte: %d\n" length (Char.code byte);
    outstring.[i * 2] <- Char.chr length;
    outstring.[i * 2 + 1] <- byte
  done;
  outstring

let chop_tail rle =
  let chopped, _ = List.fold_right
    (fun (num, byteval) (acc, saw_nonzero) ->
      if byteval = '\000' && not saw_nonzero then
        acc, saw_nonzero
      else
        (num, byteval) :: acc, true)
    rle
    ([], false) in
  chopped

let _ =
  let filename = Sys.argv.(1) in
  let outfile = Sys.argv.(2) in
  let stats = Unix.stat filename in
  let length = stats.Unix.st_size in
  let fh = open_in filename in
  let buf = String.create length in
  really_input fh buf 0 length;
  close_in fh;
  (*eorify buf;*)
  let clist = compact2 (rle buf 81920 2) in
  write clist;
  Printf.printf "Length: %d\n" (oplength clist)
  (*let encoded = encode_output (rle buf length) in
  let ofh = open_out outfile in
  output ofh encoded 0 (String.length encoded);
  close_out ofh*)
