let mixtures =
  [|
    0, 0, "", "";

    2, 0, "L", "";
    2, 2, "L", "AI";

    4, 0, "AIL", "";
    4, 2, "AIL", "B";
    4, 4, "AIL", "CKD";

    8, 0, "BFH", "";
    8, 2, "BFH", "CK";
    8, 4, "BFH", "CDK";
    8, 6, "BFH", "CDL";
    8, 8, "BFH", "CDLK";

    12, 0, "ABFHIL", "";
    12, 2, "ABFHIL", "CK";
    12, 4, "ABFHIL", "DCK";

    16, 0, "ABCDFHIKL", "";
  |]

let rgb_for_col col wt =
  (col land 1) * wt,
  ((col land 2) lsr 1) * wt,
  ((col land 4) lsr 2) * wt

let index letter =
  String.index "ABCDFHIKLP" letter

let choose_best r g b =
  let mix_len = Array.length mixtures in
  let best_dist = ref infinity
  and best_colour_mix = ref None in
  for mix = 0 to mix_len - 1 do
    let col1_wt, col2_wt, _, _ = mixtures.(mix) in
    let col3_wt = 32 - col1_wt - col2_wt in
    for col1 = 0 to 7 do
      for col2 = 0 to 7 do
        for col3 = 0 to 7 do
	  let r1, g1, b1 = rgb_for_col col1 col1_wt
	  and r2, g2, b2 = rgb_for_col col2 col2_wt
	  and r3, g3, b3 = rgb_for_col col3 col3_wt in
	  let diff_r = float_of_int ((r1 + r2 + r3) - r) *. 0.2989
	  and diff_g = float_of_int ((g1 + g2 + g3) - g) *. 0.5870
	  and diff_b = float_of_int ((b1 + b2 + b3) - b) *. 0.1140 in
	  let dist = sqrt (diff_r *. diff_r +. diff_g *. diff_g
			   +. diff_b *. diff_b) in
	  if dist < !best_dist then begin
	    best_dist := dist;
	    best_colour_mix := Some (col1, col2, col3, mix)
	  end
	done
      done
    done
  done;
  match !best_colour_mix with
    None -> raise Not_found
  | Some (c1, c2, c3, mix) ->
      let arr = Array.create 10 c3 in
      let _, _, c1cols, c2cols = mixtures.(mix) in
      for i = 0 to Array.length arr - 1 do
        String.iter (fun c -> arr.(index c) <- c1) c1cols;
	String.iter (fun c -> arr.(index c) <- c2) c2cols
      done;
      String.concat "," (List.map string_of_int (Array.to_list arr))

let pi = 4.0 *. atan 1.0

let pulse x =
  (0.5 *. cos x +. 0.5) ** 1.7

let pulse2 x =
  (0.5 *. cos x +. 0.5)

let foo () =
  for i = 0 to 127 do
    let fi = (float_of_int i) /. 64.0 in
    if fi < 1.0 then
      let two_pi_fi = 2.0 *. pi *. fi in
      let r = int_of_float (pulse (two_pi_fi) *. 32.0)
      and g = int_of_float (pulse (two_pi_fi +. 2.0 *. pi /. 3.0) *. 32.0)
      and b = int_of_float (pulse (two_pi_fi +. 4.0 *. pi /. 3.0) *. 32.0) in
      Printf.printf "pal%d: @palette %s\n" i (choose_best r g b)
    else
      let fi = fi -. 1.0 in
      let two_pi_fi = 2.0 *. pi *. fi in
      let r = int_of_float (24.0 +. cos (two_pi_fi) *. 8.0)
      and g = int_of_float (16.0 +. cos (two_pi_fi +. 1.2 *. pi /. 3.0) *. 16.0)
      and b = int_of_float (20.0 +. cos (two_pi_fi +. 3.5 *. pi /. 3.0) *. 12.0) in
      Printf.printf "pal%d: @palette %s\n" i
	(choose_best g r b)
  done

(*let _ =
  for r = 0 to 31 do
    for g = 0 to 31 do
      for b = 0 to 31 do
        Printf.printf "%s\n" (choose_best r g b)
      done
    done
  done
*)

let _ =
  foo ()
