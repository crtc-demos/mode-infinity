let remap idx =
  let char_row = (idx / 8) mod 32
  and col = idx / 256 in
  char_row * 640 + col * 8 + idx mod 8

let rle buf maxlength =
  let fetch_elem idx =
    (*let idx2 = 2 * idx in
    let b0 = Char.code buf.[remap idx2]
    and b1 = Char.code buf.[remap (idx2+1)] in
    (b1 lsl 8) lor b0 *)
    Char.code buf.[remap idx] in
  let rec count idx byteval num =
    if idx < maxlength then begin
      if fetch_elem idx = byteval && num < 192 then
	count (idx + 1) byteval (num + 1)
      else
	(num, byteval) :: count (idx + 1) (fetch_elem idx) 1
    end else
      [num, byteval] in
  count 1 (fetch_elem 0) 1

type classify =
    RLE of int * int
  | Block of int list

let compact nblist blockmax =
  let rec scan block acc = function
    [] ->
      if List.length block > 0 then
        (Block block :: acc)
      else
        acc
  | (1, byteval) :: rest ->
      if List.length block + 1 <= blockmax then
        scan (byteval :: block) acc rest
      else
        scan [byteval] (Block block :: acc) rest
  | (2, byteval) :: rest ->
      if List.length block + 2 <= blockmax then
        scan (byteval :: byteval :: block) acc rest
      else
        scan [byteval; byteval] (Block block :: acc) rest
  | (num, byteval) :: rest ->
      if List.length block > 0 then
        scan [] (RLE (num, byteval) :: Block block :: acc) rest
      else
        scan [] (RLE (num, byteval) :: acc) rest in
  scan [] [] nblist

let write clist =
  List.iter
    (function
      RLE (num, byteval) -> Printf.printf "%d x '%.2x'\n" num (byteval)
    | Block blk ->
	Printf.printf "blk (%d): %s\n" (List.length blk) (String.concat ","
	  (List.map (fun w -> Printf.sprintf "%.2x" w) blk)))
    clist

let oplength clist =
  List.fold_right
    (fun item count ->
      match item with
        RLE (num, _) -> count + 3
      | Block n -> count + 1 + 2 * (List.length n))
    clist
    0

let encode_output rle =
  let oplength = List.length rle * 2 in
  let outstring = String.create oplength in
  let arr = Array.of_list rle in
  for i = 0 to Array.length arr - 1 do
    let length, byte = arr.(i) in
    let length = if length = 256 then 0 else length in
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
  let clist = compact (rle buf (length / 2)) 64 in
  write clist;
  Printf.printf "Length: %d\n" (oplength clist)
  (*let encoded = encode_output (rle buf length) in
  let ofh = open_out outfile in
  output ofh encoded 0 (String.length encoded);
  close_out ofh*)
