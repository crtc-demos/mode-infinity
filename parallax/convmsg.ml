let chars="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!':- "

let _ =
  let message =
    "                                                                   \
    ............WELCOME TO CRTC'S NEWEST BBC MICRO DEMO PRODUCTION, PRESENTED \
    AT SUNDOWN 2013 IN BUDLEIGH SALTERTON, DEVON, UK. WE HAVE DISCOVERED A \
    NEW GRAPHICS MODE ON THE BBC MICRO, ''MODE INFINITY'', HIDDEN AS AN \
    EASTER EGG BY THE ORIGINAL DESIGNERS OF THE HARDWARE, AND LYING DORMANT \
    UNTIL NOW! THIS DEMO WILL SHOW YOU SOME OF THE NEW CAPABILITIES \
    THAT MODE INFINITY PROVIDES. THE SOUNDTRACK YOU ARE LISTENING TO IS \
    'ICE FIELDS' BY CHIP CHAMPION. GREETINGS TO EVERYONE AT THE PARTY!" in
  (*let message = "ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 .,!':-" in*)
  Printf.printf "message:\n";
  for i = 0 to String.length message - 1 do
    Printf.printf "\t.byte %d\n" (String.index chars message.[i])
  done;
  Printf.printf "message_end:\n";
  Printf.printf "\t.alias message_length message_end - message\n"
