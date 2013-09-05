/* $Id: first.c,v 1.5 1999/11/08 09:38:34 angus Exp $
 *
 * First-time routines for XFer in C
 *
 * Copyright (C) Mark de Weger 1997, Angus Duggan 1999
 *
 * Freely redistributable software. See file LICENSE for details.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "xfer.h"

bool first_time_ready(void)
{
  char ch ;

  puts("1. Make sure the serial cable is well connected\n"
       "2. Type at the BBC:\n"
       "    <BREAK>\n"
       "    *BASIC\n"
       "    *FX 7,4\n"
       "    *FX 2,1\n"
       "3. Press <ENTER> at the PC, or Q to quit") ;
  do {
    ch = toupper(keyboard_char()) ;
  } while ( ch != '\n' && ch != 'Q' ) ;

  return ch == '\n' ;
}

bool first_time_send(serial_h com, char *remote, bool autorun)
{
  FILE *bbcprog ;
  char ch, buffer[BUFSIZ + 1] ;
  int lines = 0 ;

  if ( (bbcprog = fopen(remote, "r")) == NULL )
    error("Can't open Basic program %s", remote) ;

  printf("Transferring file %s\n", remote) ;

  while ( fgets(buffer, BUFSIZ, bbcprog) ) {
    char *end = buffer + strlen(buffer) ;

    /* Ensure that lines are CR (only) terminated */
    while ( end > buffer ) {
      if ( end[-1] == '\n' || end[-1] == '\r' ) {
        *--end = '\0' ;
      } else
        break ;
    }
    *end++ = '\r' ;
    *end = '\0' ;

    if ( serial_write(com, buffer, end - buffer) != SERIAL_OK )
      error("Couldn't write whole line %s", buffer) ;

    printf("\rLine %ld", strtol(buffer, NULL, 10)) ; /* progress update */
    fflush(stdout) ;
    ++lines ;
  }
  printf("\r%d lines written\n", lines) ;

  fclose(bbcprog) ;

  if ( autorun ) {
    serial_printf(com, "RUN\r") ;

    puts("4. Press <ENTER> at the PC, or Q to quit") ;
  } else {
    serial_printf(com,
                  "REM ******************************\r"
                  "REM File Transfer Complete\r"
                  "REM Type SAVE \"XFER\" to save file\r"
                  "REM Then RUN to start program\r"
                  "REM ******************************\r"
                  "*FX 2,0\r") ;

    puts("4. SAVE the file at the BBC\n"
         "5. RUN the program at the BBC\n"
         "6. Press <ENTER> at the PC, or Q to quit") ;
  }

  do {
    ch = toupper(keyboard_char()) ;
  } while ( ch != '\n' && ch != 'Q' ) ;

  return ch == '\n' ;
}

/*
 * $Log: first.c,v $
 * Revision 1.5  1999/11/08 09:38:34  angus
 * Urgh. Revolting changes to get send file to avoid buffer overruns. Sending at
 * slow speed may be the only way to prevent this...
 *
 * Revision 1.4  1999/11/07 23:32:55  angus
 * Allow quitting before connected
 *
 * Revision 1.3  1999/11/05 02:43:05  angus
 * Linux changes; timeouts for serial read, keyboard open/close, directory
 * searching for send file.
 *
 * Revision 1.2  1999/11/02 08:36:46  angus
 * Many updates; Win32 keyboard/console/serial interface, serial transfer, info
 * file read and save.
 *
 * Revision 1.1  1999/10/27 07:01:11  angus
 * Add main.c and first.c, split first-time transfer, parameter
 * encapsulation, initial configuration, argument parsing
 *
 */
