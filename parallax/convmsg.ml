let chars="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!':- "

let _ =
  let message =
    "                                                                   \
    ...........WELCOME TO CRTC:S DEMO FOR SUNDOWN 2013 IN BUDLEIGH SALTERTON. \
    CRTC HAVE DISCOVERED A NEW GRAPHICS MODE ON THE BBC MICRO, \
    :MODE INFINITY:. THIS DEMO WILL SHOW YOU SOME OF THE NEW CAPABILITIES THAT \
    MODE INFINITY PROVIDES. GREETINGS TO GASMAN, LNX, RC55 AND EVERYONE AT \
    THE PARTY." in
  (*let message = "ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 .,!':-" in*)
  Printf.printf "message:\n";
  for i = 0 to String.length message - 1 do
    Printf.printf "\t.byte %d\n" (String.index chars message.[i])
  done;
  Printf.printf "message_end:\n";
  Printf.printf "\t.alias message_length message_end - message\n"
