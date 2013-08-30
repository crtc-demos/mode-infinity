let pi = 4.0 *. atan 1.0

let _ =
  for i = 0 to 255 do
    let iflt = ((float_of_int i) /. 256.0) *. 2.0 *. pi in
    Printf.printf ".byte %d\n" (int_of_float ((127.0 *. sin iflt) +. 0.5))
  done
