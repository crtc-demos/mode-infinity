open Color

let make_rgba32 img =
  match img with
    Images.Index8 i -> Index8.to_rgba32 i
  | Images.Index16 i -> Index16.to_rgba32 i
  | Images.Rgb24 i -> Rgb24.to_rgba32 i
  | Images.Rgba32 i -> i
  | Images.Cmyk32 i -> failwith "CMYK images unsupported"

let string_of_img_format = function
    Images.Gif -> "gif"
  | Images.Bmp -> "bmp"
  | Images.Jpeg -> "jpeg"
  | Images.Tiff -> "tiff"
  | Images.Png -> "png"
  | Images.Xpm -> "xpm"
  | Images.Ppm -> "ppm"
  | Images.Ps -> "ps"

let colour_enc { color = { Rgb.r = r; g = g; b = b }; alpha = _ } =
  let rbit = if r < 128 then 0 else 1
  and gbit = if g < 128 then 0 else 2
  and bbit = if b < 128 then 0 else 4 in
  match rbit lor gbit lor bbit with
    0 -> 0
  | 4 -> 1
  | 6 -> 2
  | 7 -> 3
  | x ->
      Printf.fprintf stderr "Bad colour %d\n" x;
      exit 1

let colour_bits enc pixnum =
  ((enc land 1) lor ((enc land 2) lsl 3)) lsl pixnum

let conv_font ht img xchars ychars =
  let indices = ref []
  and cur_idx = ref 0 in
  let hash_row ht row =
    let idx =
      try
	Hashtbl.find ht row
      with Not_found ->
        let add_idx = !cur_idx in
	Hashtbl.add ht row add_idx;
	incr cur_idx;
	add_idx in
    indices := idx :: !indices in
  for y = 0 to ychars - 1 do
    for x = 0 to xchars - 1 do
      let xcpos = x * 16
      and ycpos = y * 16 in
      for col = 0 to 3 do
        let rowlist = ref [] in
        for row = 0 to 15 do
	  let pix0 = Rgba32.get img (xcpos + 4 * col) (ycpos + row)
	  and pix1 = Rgba32.get img (xcpos + 4 * col + 1) (ycpos + row)
	  and pix2 = Rgba32.get img (xcpos + 4 * col + 2) (ycpos + row)
	  and pix3 = Rgba32.get img (xcpos + 4 * col + 3) (ycpos + row) in
	  let byte =
	    (colour_bits (colour_enc pix0) 3)
	    lor (colour_bits (colour_enc pix1) 2)
	    lor (colour_bits (colour_enc pix2) 1)
	    lor (colour_bits (colour_enc pix3) 0) in
	  rowlist := byte :: !rowlist
	done;
	hash_row ht !rowlist
      done
    done
  done;
  !indices, !cur_idx

let _ =
  let infile = ref ""
  and outfile = ref "" in
  let argspec =
    ["-o", Arg.Set_string outfile, "Set output file"]
  and usage = "Usage: fontconv infile -o outfile" in
  Arg.parse argspec (fun name -> infile := name) usage;
  if !infile = "" || !outfile = "" then begin
    Arg.usage argspec usage;
    exit 1
  end;
  let img = Images.load !infile [] in
  let xsize, ysize = Images.size img in
  (*Printf.fprintf stderr "Got image: size %d x %d\n" xsize ysize;*)
  let ht = Hashtbl.create 5 in
  let indices, num = conv_font ht (make_rgba32 img) (xsize / 16) (ysize / 16) in
  Printf.fprintf stderr "Unique columns: %d\n" num;
  let fo = open_out !outfile in
  (*List.iter (fun idx -> Printf.printf "idx: %n\n" idx) indices*)
  let iht = Hashtbl.create 5 in
  Hashtbl.iter
    (fun k v -> Hashtbl.add iht v k)
    ht;
  Printf.fprintf fo "font_columns:\n";
  for i = 0 to num - 1 do
    let column = Hashtbl.find iht i in
    List.iter (fun n -> Printf.fprintf fo "\t.byte %d\n" n) (List.rev column)
  done;
  Printf.fprintf fo "font_index:\n";
  List.iter (fun n -> Printf.fprintf fo "\t.byte %d\n" n) (List.rev indices);
  close_out fo
