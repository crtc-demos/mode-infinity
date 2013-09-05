/* $Id: main.c,v 1.6 1999/11/07 23:32:55 angus Exp $
 *
 * XFer in C
 *
 * Copyright (C) Mark de Weger 1997, Angus Duggan 1999
 *
 * Freely redistributable software. See file LICENSE for details.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "xfer.h"

static char *program = NULL ;
static bool opened_kbd = false ;

void usage(void)
{
  fprintf(stderr, "XFer in C version %.2f\n"
          "Copyright Mark de Weger 1997, Angus J. C. Duggan 1999\n"
	  "Usage: %s [-b baud] [-c port] [-t timeout] [-h ctsrts|dsrdtr|xonxoff] [-d on|off] [-w on|off] [-1|-1st] [-r]\n"
          "\t-b baud\t\tset baud rate (default 9600)\n"
          "\t-c port\t\tset COM port\n"
          "\t-t timeout\tCOM port timeout in 1/100 seconds\n"
          "\t-h ctsrts|dsrdtr|xonxoff\tset handshake method\n"
          "\t-d on|off\tallow or disallow directory usage\n"
          "\t-w on|off\tallow or disallow wildcard usage\n"
          "\t-1|1st\t\tfirst connection to BBC, download xfer.bas\n"
          "\t-r\t\tRUN xfer.bas after downloading (requires -1)\n",
          XFER_VERSION, program) ;
  exit(1) ;
}

void error(char *format, ...)
{
  va_list args ;
  char *scan = format, ch ;

  fprintf(stderr, "%s: ", program) ;
  va_start(args, format) ;
  while ( (ch = *scan++) != '\0' ) {
    if ( ch == '%' ) {
      switch ( *scan++ ) {
      case 'd':
	fprintf(stderr, "%d", va_arg(args, int)) ;
	break ;
      case 's':
	fprintf(stderr, "%s", va_arg(args, char *)) ;
	break ;
      case '%':
	fputc(ch, stderr) ;
	break ;
      default:
	fprintf(stderr, "Bad format string\n") ;
	exit(1) ;
      }
    } else
      fputc(ch, stderr) ;
  }
  fputc('\n', stderr) ;
  fflush(stderr) ;
  va_end(args) ;

  if ( opened_kbd )
    keyboard_close() ;

  exit(1) ;
}

void serial_printf(serial_h connection, char *format, ...)
{
  va_list args ;
  char *scan = format, *start = format, *end ;

  va_start(args, format) ;
  while ( *(end = scan++) != '\0' ) {
    if ( *end == '%' ) {
      if ( end > start ) {
        switch ( serial_write(connection, start, end - start) ) {
        case SERIAL_ERROR:
          error("Communication failure") ;
        case SERIAL_TIMEOUT: /* Want more sensible error handling here */
          error("Connection timed out") ;
        }
      }

      switch ( *scan++ ) {
      case 'd': {
	long arg = va_arg(args, long) ;
        char intbuf[15] ;

        sprintf(intbuf, "%ld", arg) ;

        switch ( serial_write(connection, intbuf, strlen(intbuf)) ) {
        case SERIAL_ERROR:
          error("Communication failure") ;
        case SERIAL_TIMEOUT: /* Want more sensible error handling here */
          error("Connection timed out") ;
        }
        start = scan ;
	break ;
      }
      case 's': {
        char *strbuf = va_arg(args, char *) ;
        long len = strlen(strbuf) ;
        if ( len > 0 ) {
          switch ( serial_write(connection, strbuf, len) ) {
          case SERIAL_ERROR:
            error("Communication failure") ;
          case SERIAL_TIMEOUT: /* Want more sensible error handling here */
            error("Connection timed out") ;
          }
        }
        start = scan ;
	break ;
      }
      case 'c': {
        char chbuf[1] ;

        chbuf[0] = (char)va_arg(args, int) ;
        switch ( serial_write(connection, chbuf, 1) ) {
        case SERIAL_ERROR:
          error("Communication failure") ;
        case SERIAL_TIMEOUT: /* Want more sensible error handling here */
          error("Connection timed out") ;
        }
        start = scan ;
	break ;
      }
      case '%':
        start = scan - 1 ;
	break ;
      default:
	fprintf(stderr, "Bad format string\n") ;
	exit(1) ;
      }
    }
  }
  if ( end > start ) {
    switch ( serial_write(connection, start, end - start) ) {
    case SERIAL_ERROR:
      error("Communication failure") ;
    case SERIAL_TIMEOUT: /* Want more sensible error handling here */
      error("Connection timed out") ;
    }
  }
  va_end(args) ;
}

static char spare_buf[MAXLINELEN] ;
static char *spare = NULL ;
static long spare_len = 0 ;

bbc_status_t bbc_readline(serial_h com, char *buffer, long size)
{
  char *start = buffer, *end = NULL ;
  bbc_status_t result = BBC_OK ;
  long part ;

  do {
    part = size ;

    if ( spare_len > 0 ) { /* Use leftover from previous read first */
      if ( spare_len < part )
        part = spare_len ;
      memcpy(buffer, spare, part) ;
      spare += part ;
      spare_len -= part ;
    } else {
      switch ( serial_read(com, buffer, &part) ) {
      case SERIAL_TIMEOUT:
        return BBC_ERROR ;
      case SERIAL_ERROR:
        error("Problem reading line from serial port") ;
      }
    }

    buffer += part ;
    size -= part ;
  } while ( (end = memchr(buffer - part, '\r', part)) == NULL && size > 0 ) ;

  if ( !end )
    error("BBC sent line too long (%d chars)", buffer - start) ;

  if ( end != buffer - 1 ) { /* Store away spare */
    long leftover = buffer - end - 1 ;

    if ( leftover + spare_len > MAXLINELEN )
      error("Internal error. Increase leftover buffer size") ;

    if ( spare_len )
      memmove(spare_buf + leftover, spare, spare_len) ;

    memcpy(spare_buf, end + 1, leftover) ;
    spare = spare_buf ;
    spare_len += leftover ;
  }

  if ( end > start && end[-1] == '\n' )
    --end ;

  /* See if end of response was sync or error text, note type and remove */
  if ( memcmp(end - TEXT_SYNC_LEN, TEXT_SYNC, TEXT_SYNC_LEN) == 0 ) {
    result = BBC_SYNC ;
    end -= TEXT_SYNC_LEN ;
  } else if ( memcmp(end - ERR_TXT_LEN, ERR_TXT, ERR_TXT_LEN) == 0 ) {
    result = BBC_ERROR ;
    end -= ERR_TXT_LEN ;
  } else if ( memcmp(end - ERR_TXT2_LEN, ERR_TXT2, ERR_TXT2_LEN) == 0 ) {
    result = BBC_ERROR_2 ;
    end -= ERR_TXT2_LEN ;
  }

  *end = '\0' ; /* Terminate line */

  return result ;
}

/* Wrapper for serial_read that uses up spare buf first */
bbc_status_t bbc_read(serial_h com, char *buffer, long *size)
{
  if ( spare_len > 0 ) {
    if ( spare_len < *size )
      *size = spare_len ;
    memcpy(buffer, spare, *size) ;
    spare += *size ;
    spare_len -= *size ;
    return BBC_OK ;
  }

  switch ( serial_read(com, buffer, size) ) {
  case SERIAL_TIMEOUT:
    return BBC_ERROR ;
  case SERIAL_ERROR:
    error("Problem reading buffer from serial port") ;
  }

  return BBC_OK ;
}

/* Utility conversion functions, for use by initialisation file parsing */
static long baudrates[N_BAUD_RATES] = { 1200, 2400, 4800, 9600, 19200 } ;

bool itobaud(long baud, baud_rate_t *value)
{
  baud_rate_t index ;

  for ( index = XFER_B1200 ; index < N_BAUD_RATES ; ++index )
    if ( baud == baudrates[index] ) {
      *value = index ;
      return true ;
    }

  return false ;
}

long baudtoi(baud_rate_t value)
{
  return baudrates[value] ;
}

bool strtobool(char *str, bool *value)
{
  if ( strcmp(str, "on") == 0 || strcmp(str, "yes") == 0 ||
       strcmp(str, "true") == 0 || strcmp(str, "1") == 0 ) {
    *value = true ;
    return true ;
  } else if ( strcmp(str, "off") == 0 || strcmp(str, "no") == 0 ||
            strcmp(str, "false") == 0 || strcmp(str, "0") == 0 ) {
    *value = false ;
    return true ;
  }

  return false ;
}

bool strtohandshake(char *str, handshake_t *value)
{
  if ( strcmp(str, "xonxoff") == 0 || strcmp(str, "xon_xoff") == 0 ) {
    *value = HANDSHAKE_XON_XOFF ;
    return true ;
  } else if ( strcmp(str, "ctsrts") == 0 || strcmp(str, "cts_rts") == 0 ) {
    *value = HANDSHAKE_CTS_RTS ;
    return true ;
  } else if ( strcmp(str, "dsrdtr") == 0 || strcmp(str, "dsr_dtr") == 0 ) {
    *value = HANDSHAKE_DSR_DTR ;
    return true ;
  }

  return false ;
}

/* Main routine to parse arguments and call appropriate dialogue functions */
int main(int argc, char *argv[])
{
  configuration_t config ;
  serial_h com ;
  bool firsttime = false ;
  bool autorun = false ;

  /* Set common configuration */
  config.basic = "xfer.bas" ; /* BASIC program filename */
  config.baudrate = XFER_B9600 ;
  config.directories = true ;
  config.wildcards = true ;
  config.handshake = HANDSHAKE_DSR_DTR ;
  config.timeoutdelay = 1000 ; /* 10 seconds */

  if ( (program = strrchr(*argv, '/')) == NULL &&
       (program = strrchr(*argv, '\\')) == NULL )
    program = *argv ;
  else
    ++program ;

  /* Rest of configuration and user defaults */
  default_configuration(&config) ;

  for ( argv++ ; --argc ; argv++ ) {
    if ( argv[0][0] == '-' ) {
      char ch = argv[0][1] ;
      char *optarg = NULL ;

      if ( strchr("bcdwth", ch) != NULL ) {
        if ( argv[0][2] )
          optarg = &argv[0][2] ;
        else if ( --argc )
          optarg = *++argv ;
        else
          usage() ;
      }

      switch ( ch ) {
      case 'b': /* Baud rate */
        if ( !itobaud(strtol(optarg, &optarg, 10), &config.baudrate) ||
             *optarg != '\0' )
          usage() ;
        break ;
      case 'c': /* COM port */
        config.comport = optarg ;
        break ;
      case 'd': /* Directories allowed */
        if ( !strtobool(optarg, &config.directories) )
          usage() ;
        break ;
      case 'w': /* Wildcards allowed */
        if ( !strtobool(optarg, &config.wildcards) )
          usage() ;
        break ;
      case 'h': /* Handshaking */
        if ( !strtohandshake(optarg, &config.handshake) )
          usage() ;
        break ;
      case 't': /* Timeout in seconds */
        if ( (config.timeoutdelay = strtol(optarg, &optarg, 10)) < 1 ||
             *optarg != '\0' ) {
          usage() ;
        } else if ( config.timeoutdelay < 200 ) {
          /* We normally read lines of 256 bytes. To retrieve this at 1200
             baud will take approx 2.13 seconds at maximum flow rate. */
          printf("Timeout value %ld less than 2 seconds may cause failures\n", config.timeoutdelay) ;
        }
        break ;
      case '1': /* First time */
        if ( argv[0][2] != '\0' && strcmp("-1st", *argv) != 0 )
          usage() ;
        firsttime = true ;
        break ;
      case 'r': /* RUN after downloading first time */
        autorun = true ;
        break ;
      default:
        usage() ;
      }
    } else
      usage() ;
  }

  if ( autorun && !firsttime )
    error("-r option not useful without -1") ;

  interrupt_catch() ;

  keyboard_open() ;
  opened_kbd = true ;

  printf("%s:\tTransfers files in archive format (with .inf file) to and\n"
         "\tfrom BBC computers via a serial link.\n"
         "\n"
         "Copyright (C) 1996-1997 Mark de Weger, 1999 Angus Duggan\n"
         "\n", program) ;

  if ( firsttime ) {
    if ( !first_time_ready() ) {
      keyboard_close() ;
      puts("Quitting...") ;
      return 1 ;
    }
  } else
    puts("Make sure XFer/BBC is running on the BBC.\n") ;

  printf("Connecting to COM port %s\n", config.comport) ;

  if ( serial_open(&config, &com) != SERIAL_OK )
    error("Problem opening COM port %s", config.comport) ;

  /* Send BASIC program to BBC */
  if ( firsttime ) {
    if ( !first_time_send(com, config.basic, autorun) ) {
      serial_close(com) ;
      keyboard_close() ;
      puts("Quitting...") ;
      return 1 ;
    }
  }

  /* Send synchronisation text, protocol and baud rate */
  serial_printf(com, "%s\r%d\r%d\r", TEXT_SYNC, XFER_PROTOCOL_VERSION,
                baudtoi(config.baudrate)) ;

  /* Force characters out before re-configuring */
  serial_flush(com) ;

  printf("Connected at %ld baud, handshake %s, timeout %.2f seconds,\n"
         "directories %s allowed, wildcards %s allowed\n",
         baudtoi(config.baudrate), "DSR/DTR", config.timeoutdelay / 100.0,
         config.directories ? "are" : "not",
         config.wildcards ? "are" : "not") ;

  /* Re-configure to desired baud rate */
  if ( serial_config(com, &config) != SERIAL_OK )
    error("Problem re-configuring COM port %s", config.comport) ;

  xfer(com, &config) ;

  serial_flush(com) ;

  serial_close(com) ;

  keyboard_close() ;

  return 0 ;
}

/*
 * $Log: main.c,v $
 * Revision 1.6  1999/11/07 23:32:55  angus
 * Allow quitting before connected
 *
 * Revision 1.5  1999/11/06 23:04:20  angus
 * Add local and remote checksums, correct messages, quit from disc image
 * retrieve, subroutines for filespecs, dot file fixes.
 *
 * Revision 1.4  1999/11/05 02:43:05  angus
 * Linux changes; timeouts for serial read, keyboard open/close, directory
 * searching for send file.
 *
 * Revision 1.3  1999/11/04 09:21:16  angus
 * Many more changes. Altered some protocols, added text files, renumber script,
 * rewrite machine code, add track return, send file, match files, etc.
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
