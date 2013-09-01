type commands =
    Latch_tone of int * int
  | Latch_vol of int * int
  | Data_byte of int
  | Set_vol of int * int
  | Set_tone of int * int
  | Wait of int
  | End_of_sound
  | Unknown of int

let string_of_cmd = function
    Set_tone (c, n) -> Printf.sprintf "Set tone, channel %d to %d" c n
  | Set_vol (c, n) -> Printf.sprintf "Set volume, channel %d to %d" c n
  | Latch_tone (c, n) -> Printf.sprintf "Latch tone, channel %d to %d" c n
  | Latch_vol (c, n) -> Printf.sprintf "Latch volume, channel %d to %d" c n
  | Data_byte n -> Printf.sprintf "Data byte %d" n
  | Wait n -> Printf.sprintf "Wait %d samples" n
  | End_of_sound -> "End of sound"
  | Unknown n -> Printf.sprintf "Unknown command 0x%2x" n

let merge_databytes cmdstream =
  let rec join cmds last_latched latch_written acc =
    match cmds with
      [] -> acc
    | cmd :: rest ->
        (*begin match cmd, last_latched with
	  c, None -> Printf.printf "Command: %s\n" (string_of_cmd c)
	| c, Some l -> Printf.printf "Command: %s, last latched: %s\n"
	  (string_of_cmd c) (string_of_cmd l)
	end;*)
        begin match cmd, last_latched with
	  Latch_tone _, None -> join rest (Some cmd) false acc
	| Latch_vol _, None -> join rest (Some cmd) false acc
	| Latch_tone (c, n), Some l ->
	    if latch_written then
	      join rest (Some cmd) false acc
	    else
	      join rest (Some cmd) false (l :: acc)
	| Latch_vol (c, n), Some l ->
	    if latch_written then
	      join rest (Some cmd) false acc
	    else
	      join rest (Some cmd) false (l :: acc)
	| Data_byte lo, Some (Latch_tone (c, hi)) ->
	    let tone = if c = 3 then lo else (hi lsl 6) lor lo in
	    join rest last_latched true (Set_tone (c, tone) :: acc)
	| Data_byte lo, Some (Latch_vol (c, hi)) ->
	    (* This is an atypical case.  *)
	    join rest last_latched true
	      (Set_vol (c, lo land 15) :: acc)
	| Wait _, None -> join rest None true (cmd :: acc)
	| Wait _, Some l ->
	    (* Wait, but also send the latched value to the PSG & remember what
	       the last thing we latched was.  *)
	    if latch_written then
	      join rest last_latched true (cmd :: acc)
	    else
	      join rest last_latched true (cmd :: l :: acc)
	| x, _ -> join rest last_latched latch_written (x :: acc)
	end in
  List.rev (join cmdstream None false [])

let latches_to_sets cmdstream =
  let rec scan acc = function
    [] -> List.rev acc
  | cmd::cmds ->
      let cmd' =
        begin match cmd with
          Latch_vol (c, n) -> Set_vol (c, n land 15)
	| Latch_tone (c, n) ->
            if c = 3 then
	      Set_tone (c, n land 7)
	    else begin
	      Printf.fprintf stderr "Latch tone without data byte %d, %d" c n;
	      Set_tone (c, n)
	    end
	| x -> x
	end in
      scan (cmd' :: acc) cmds in
  scan [] cmdstream

let gather_freqs cmdstream =
  let ht = Hashtbl.create 5 in
  List.iter
    (function
      Set_tone (_, n) -> Hashtbl.replace ht n ()
    | _ -> ())
    cmdstream;
  List.sort compare (Hashtbl.fold (fun k () a -> k::a) ht [])

(*let all_substrings lst =
  let rec scan st en acc =
    match st, en with
      [], [] -> acc
    | a, [] -> a :: acc
    | [], b -> b :: acc
    | al, b::bl -> scan (al @ [b]) bl (st :: en :: acc) in
  match lst with
    [] -> []
  | a::al -> scan [a] al []*)

let volume_envelopes cmdstream chan timestep beat =
  let rec scan cmds cur_time song_time cur_vol cur_beat acc all =
    if cur_time < song_time then begin
      let this_beat = (cur_time / timestep) / beat in
      (*let in_beat = (cur_time / timestep) mod beat in
      Printf.printf "%d/%d : %d\n" this_beat in_beat cur_vol;*)
      let acc', all' =
        if this_beat = cur_beat then (cur_vol :: acc), all
	else [cur_vol], (acc :: all) in
      scan cmds (cur_time + timestep) song_time cur_vol this_beat acc' all'
    end else begin
      match cmds with
	[] -> all
      | Set_vol (c, n) :: rest when c = chan ->
	  scan rest cur_time song_time n cur_beat acc all
      | Wait w :: rest ->
	  scan rest cur_time (song_time + w) cur_vol cur_beat acc all
      | _ :: rest ->
	  scan rest cur_time song_time cur_vol cur_beat acc all
    end in
  scan cmdstream 0 0 15 0 [] []

let uniquify_envelopes lls =
  let ht = Hashtbl.create 5 in
  let idx = ref 0 in
  List.iter
    (fun ll ->
      List.iter
	(fun vol_env ->
	  if not (Hashtbl.mem ht vol_env) then begin
            Hashtbl.add ht vol_env !idx;
	    incr idx
	  end)
	ll)
    lls;
  (*Hashtbl.iter
    (fun k v ->
      Printf.printf "%d: %s\n" v
        (String.concat "," (List.map string_of_int (List.rev k))))
    ht;*)
  ht

let pitch_envelopes cmdstream chan timestep beat pitch_ht =
  let pitch_idx n =
    Hashtbl.find pitch_ht n in
  let rec scan cmds cur_time song_time zero_pitch cur_pitch cur_beat acc all =
    if cur_time < song_time then begin
      let this_beat = (cur_time / timestep) / beat in
      let in_beat = (cur_time / timestep) mod beat in
      let zero_pitch', rel_pitch =
        if in_beat = 0 then cur_pitch, 0
	else zero_pitch, cur_pitch - zero_pitch in
      let acc', all' =
        if this_beat = cur_beat then (rel_pitch :: acc), all
	else [rel_pitch], (acc :: all) in
      scan cmds (cur_time + timestep) song_time zero_pitch' cur_pitch this_beat
	   acc' all'
    end else begin
      match cmds with
        [] -> all
      | Set_tone (c, n) :: rest when c = chan ->
	  scan rest cur_time song_time zero_pitch (pitch_idx n) cur_beat acc all
      | Wait w :: rest ->
	  scan rest cur_time (song_time + w) zero_pitch cur_pitch cur_beat
	       acc all
      | _ :: rest ->
	  scan rest cur_time song_time zero_pitch cur_pitch cur_beat acc all
    end in
  scan cmdstream 0 0 0 0 0 [] []

let run_conversion cmdstream chan timestep beat peht veht pitch_ht =
  let pitch_idx n =
    Hashtbl.find pitch_ht n in
  let rec scan cmds cur_time song_time zero_pitch cur_pitch cur_vol cur_beat
	       acc all =
    if cur_time < song_time then begin
      let this_beat = (cur_time / timestep) / beat in
      let in_beat = (cur_time / timestep) mod beat in
      let zero_pitch', rel_pitch =
        if in_beat = 0 then cur_pitch, 0
	else zero_pitch, cur_pitch - zero_pitch in
      let acc' =
        if this_beat = cur_beat then ((rel_pitch, cur_vol) :: acc)
	else [rel_pitch, cur_vol] in
      let all' =
        if this_beat = cur_beat then
	  all
	else begin
	  let pitches = List.map fst acc
	  and vols = List.map snd acc in
	  let pidx = Hashtbl.find peht pitches
	  and vidx = Hashtbl.find veht vols in
	  (zero_pitch, pidx, vidx) :: all
	end in
      scan cmds (cur_time + timestep) song_time zero_pitch' cur_pitch cur_vol
	   this_beat acc' all'
    end else begin
      match cmds with
        [] -> all
      | Set_tone (c, n) :: rest when c = chan ->
          scan rest cur_time song_time zero_pitch (pitch_idx n) cur_vol
	       cur_beat acc all
      | Set_vol (c, n) :: rest when c = chan ->
	  scan rest cur_time song_time zero_pitch cur_pitch n cur_beat acc all
      | Wait w :: rest ->
	  scan rest cur_time (song_time + w) zero_pitch cur_pitch cur_vol
	       cur_beat acc all
      | _ :: rest ->
	  scan rest cur_time song_time zero_pitch cur_pitch cur_vol cur_beat
	       acc all
    end in
  List.rev (scan cmdstream 0 0 0 0 0 0 [] [])

let convert_file filename =
  let tick = 735
  and beat_len = 18
  and prefix = "song_" in
  let fh = open_in_bin filename in
  let inlen = in_channel_length fh in
  let inbuf = String.create inlen in
  really_input fh inbuf 0 inlen;
  let get_byte n = Char.code inbuf.[n] in
  let get_word n =
    get_byte n lor ((get_byte (n + 1)) lsl 8) in
  let get_dword n =
    let b0 = Int32.of_int (get_byte n)
    and b1 = Int32.shift_left (Int32.of_int (get_byte (n + 1))) 8
    and b2 = Int32.shift_left (Int32.of_int (get_byte (n + 2))) 16
    and b3 = Int32.shift_left (Int32.of_int (get_byte (n + 3))) 24 in
    Int32.logor b0 (Int32.logor b1 (Int32.logor b2 b3)) in
  let filetype = get_dword 0 in
  if filetype <> 0x206d6756l then begin
    prerr_endline "Input doesn't look like a VGM file.";
    exit 1
  end;
  let data_offset = get_dword 0x34 in
  let data_offset =
    if data_offset = 0l then 0x40l else Int32.add data_offset 0x34l in
  (*Printf.printf "Data starts at: %ld\n" data_offset;*)
  let idx = ref (Int32.to_int data_offset) in
  let found_end = ref false in
  let outlist = ref [] in
  while !idx < inlen && not !found_end do
    let cmd, cmdlen =
      match get_byte !idx with
	0x50 ->
	  let byte = get_byte (!idx + 1) in
	  if byte land 0x80 <> 0 then begin
	    let chan = (byte lsr 5) land 3
	    and data = byte land 15 in
	    if byte land 16 <> 0 then
	      Latch_vol (chan, data), 2
	    else
	      Latch_tone (chan, data), 2
	  end else begin
	    let data = byte land 63 in
	    Data_byte data, 2
	  end
      | 0x61 -> Wait (get_word (!idx + 1)), 3
      | 0x62 -> Wait 735, 1
      | 0x63 -> Wait 882, 1
      | 0x66 -> End_of_sound, 1
      | x when x >= 0x70 && x <= 0x7f -> Wait (x - 0x70), 1
      | x -> Unknown x, 1
      in
    idx := !idx + cmdlen;
    if cmd = End_of_sound then
      found_end := true
    else
      outlist := cmd :: !outlist
  done;
  outlist := List.rev !outlist;
  (*Printf.printf "Before:\n";
  List.iter (fun cmd -> Printf.printf "%s\n" (string_of_cmd cmd)) !outlist;*)
  let outlist = merge_databytes !outlist in
  let outlist = latches_to_sets outlist in
  Printf.printf "After:\n";
  List.iter (fun cmd -> Printf.printf "%s\n" (string_of_cmd cmd)) outlist;
  let freqtab = gather_freqs outlist in
  let fidx = ref 0
  and fht = Hashtbl.create 5 in
  List.iter
    (fun freq ->
      Hashtbl.add fht freq !fidx;
      (*Printf.printf "%d -> %d\n" freq !fidx;*)
      incr fidx)
    freqtab;
  let ll0 = volume_envelopes outlist 0 tick beat_len
  and ll1 = volume_envelopes outlist 1 tick beat_len
  and ll2 = volume_envelopes outlist 2 tick beat_len
  and ll3 = volume_envelopes outlist 3 tick beat_len in
  let vol_env = uniquify_envelopes [ll0; ll1; ll2; ll3] in
  let pe0 = pitch_envelopes outlist 0 tick beat_len fht
  and pe1 = pitch_envelopes outlist 1 tick beat_len fht
  and pe2 = pitch_envelopes outlist 2 tick beat_len fht
  and pe3 = pitch_envelopes outlist 3 tick beat_len fht in
  let pitch_env = uniquify_envelopes [pe0; pe1; pe2; pe3] in
  let c0 = run_conversion outlist 0 tick beat_len pitch_env vol_env fht
  and c1 = run_conversion outlist 1 tick beat_len pitch_env vol_env fht
  and c2 = run_conversion outlist 2 tick beat_len pitch_env vol_env fht
  and c3 = run_conversion outlist 3 tick beat_len pitch_env vol_env fht in
  let rec output_song fo c0 c1 c2 c3 =
    match c0, c1, c2, c3 with
      (zp0, pei0, vei0) :: c0s,
      (zp1, pei1, vei1) :: c1s,
      (zp2, pei2, vei2) :: c2s,
      (zp3, pei3, vei3) :: c3s ->
        Printf.fprintf fo "\t.byte %d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n"
	  zp0 pei0 vei0 zp1 pei1 vei1 zp2 pei2 vei2 zp3 pei3 vei3;
	output_song fo c0s c1s c2s c3s
    | [], [], [], [] -> ()
    | _ -> Printf.fprintf stderr "Mismatched channel lengths!\n"; exit 1 in
  let fo = open_out Sys.argv.(2) in
  Printf.fprintf fo "%sfreqtab:\n" prefix;
  let ifht = Hashtbl.create 5 in
  Hashtbl.iter (fun k v -> Hashtbl.add ifht v k) fht;
  for i = 0 to !fidx - 1 do
    let freq = Hashtbl.find ifht i in
    let hipart = (freq lsr 6) land 15
    and lopart = freq land 63 in
    Printf.fprintf fo "\t.word %d\n" ((hipart lsl 8) lor lopart)
  done;
  Printf.fprintf fo "%svolenv:\n" prefix;
  let ivolenv = Hashtbl.create 5 in
  Hashtbl.iter (fun k v -> Hashtbl.add ivolenv v k) vol_env;
  for i = 0 to Hashtbl.length ivolenv - 1 do
    Printf.fprintf fo "\t.byte %s\n"
      (String.concat "," (List.rev_map string_of_int (Hashtbl.find ivolenv i)))
  done;
  Printf.fprintf fo "%spitchenv:\n" prefix;
  let ipitchenv = Hashtbl.create 5 in
  Hashtbl.iter (fun k v -> Hashtbl.add ipitchenv v k) pitch_env;
  for i = 0 to Hashtbl.length ipitchenv - 1 do
    Printf.fprintf fo "\t.byte %s\n"
      (String.concat "," (List.rev_map string_of_int (Hashtbl.find ipitchenv i)))
  done;
  Printf.fprintf fo "%snotes:\n" prefix;
  output_song fo c0 c1 c2 c3;
  close_out fo
  
  (*List.iter
    (fun pe ->
      Printf.printf "%s\n" (String.concat "," (List.map string_of_int pe)))
    pe0*)

let _ =
  let infile = Sys.argv.(1) in
  convert_file infile
