#ifdef LINUX
/* $Id: linux.c,v 1.7 1999/11/08 09:38:34 angus Exp $
 *
 * Linux routines for XFer in C
 *
 * Copyright (C) Mark de Weger 1997, Angus Duggan 1999
 *
 * Freely redistributable software. See file LICENSE for details.
 */

#define _BSD_SOURCE /* CRTSCTS */
#define _POSIX_SOURCE /* fileno */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <malloc.h>
#include <string.h>
#include <ctype.h>
#include <signal.h>
#include <dirent.h>

#include "xfer.h"

/****************************************************************************/

/* Serial port control functions */
typedef struct {
  int fd ;
  struct termios oldtio ;
} serial_attrs ;

serial_status_t serial_open(configuration_t *config, serial_h *connection)
{
  serial_attrs *attrs = malloc(sizeof(serial_attrs)) ;
  configuration_t lconfig = *config ;
  int fd ;

  if ( !attrs || (fd = open(lconfig.comport, O_RDWR | O_NOCTTY)) < 0 )
    return SERIAL_ERROR ;

  attrs->fd = fd ;
  if ( tcgetattr(fd, &attrs->oldtio) < 0 )
    return SERIAL_ERROR ;
  
  *connection = (serial_h)attrs ;

  lconfig.baudrate = XFER_B1200 ;

  return serial_config((serial_h)attrs, &lconfig) ;
}

serial_status_t serial_config(serial_h connection, configuration_t *config)
{
  serial_attrs *attrs = (serial_attrs *)connection ;
  struct termios newtio ;
  int timeout ;

  static int baud_rates[N_BAUD_RATES] = {
    B1200, B2400, B4800, B9600, B19200
  } ;

  memset(&newtio, 0, sizeof(newtio)); /* clear struct for new port settings */

  /*
    BAUDRATE: Set bps rate. You could also use cfsetispeed and cfsetospeed.
    CRTSCTS : output hardware flow control (only used if the cable has
              all necessary lines. See sect. 7 of Serial-HOWTO)
    CS8     : 8n1 (8bit,no parity,1 stopbit)
    CLOCAL  : local connection, no modem contol
    CREAD   : enable receiving characters
  */
  newtio.c_cflag = baud_rates[config->baudrate] | CRTSCTS | CS8 | CLOCAL | CREAD;

  /*
    IGNPAR  : ignore bytes with parity errors
  */
  newtio.c_iflag = IGNPAR|IGNBRK;

  /*
   Raw output.
  */
  newtio.c_oflag = 0;

  /*
    ICANON  : enable canonical input
    disable all echo functionality, and don't send signals to calling program
  */
  newtio.c_lflag = 0;

  timeout = config->timeoutdelay / 10 ;
  if ( timeout < 1 )
    timeout = 1 ;
  else if ( timeout >= (1 << 8 * sizeof(newtio.c_cc[VTIME])) )
    timeout = (1 << 8 * sizeof(newtio.c_cc[VTIME])) - 1 ;

  newtio.c_cc[VTIME]    = timeout ; /* Timeout * 0.1s */
  newtio.c_cc[VMIN]     = 0;        /* Don't require any characters */

  if ( tcdrain(attrs->fd) < 0 ||
       tcsetattr(attrs->fd, TCSADRAIN, &newtio) < 0 )
    return SERIAL_ERROR ;

  return SERIAL_OK ;
}

serial_status_t serial_write(serial_h connection, char *buffer, int size)
{
  serial_attrs *attrs = (serial_attrs *)connection ;

  while ( size > 0 ) {
    int written = write(attrs->fd, buffer, size) ;
    if ( written < 0 )
      return SERIAL_ERROR ;
    if ( written == 0 )
      return SERIAL_TIMEOUT ;
    buffer += written ;
    size -= written ;
  }
  
  return SERIAL_OK ;
}

serial_status_t serial_read(serial_h connection, char *buffer, int *size)
{
  serial_attrs *attrs = (serial_attrs *)connection ;

  *size = read(attrs->fd, buffer, *size) ;

  if ( *size < 0 )
    return SERIAL_ERROR ;

  if ( *size == 0 )
    return SERIAL_TIMEOUT ;
  
  return SERIAL_OK ;
}

serial_status_t serial_flush(serial_h connection)
{
  serial_attrs *attrs = (serial_attrs *)connection ;

  if ( tcdrain(attrs->fd) < 0 )
    return SERIAL_ERROR ;

  return SERIAL_OK ;
}

void serial_close(serial_h connection)
{
  serial_attrs *attrs = (serial_attrs *)connection ;

  (void)tcflush(attrs->fd, TCIFLUSH) ;
  (void)tcsetattr(attrs->fd, TCSANOW, &attrs->oldtio) ;

  close(attrs->fd) ;
}

/****************************************************************************/

/* Default and user configuration functions */
#define DOTXFER "/.xfer" /* What to append to $HOME for config file */

void default_configuration(configuration_t *config)
{
  char *home ;
  
  FILE *dotxfer = NULL ;

  /* Default configuration */
  config->comport = "/dev/ttyS0" ;

  /* User configuration */
  if ( (home = getenv("HOME")) != NULL ) {
    char *filename = malloc(strlen(home) + strlen(DOTXFER)) ;

    if ( !filename )
      error("Out of memory allocating filename space") ;

    strcpy(filename, home) ;
    strcat(filename, DOTXFER) ;

    /* Try to find ~/.xfer, and read it */
    if ( (dotxfer = fopen(filename, "r")) != NULL ) {
      char buffer[BUFSIZ] ;

      while ( fgets(buffer, BUFSIZ, dotxfer) ) {
        char *scan = buffer, *start, *arg ;

        while ( isspace(*scan) ) ++scan ;

        if ( *scan == '#' || *scan == '\0' ) /* Comment or blank line */
          continue ;

        /* Find end of command */
        for ( start = scan ; *scan && !isspace(*scan) ; ++scan ) ;

        /* Find argument */
        if ( *(arg = scan) != '\0' )
          for ( *arg++ = '\0' ; isspace(*arg) ; ++arg ) ;

        /* Find end of argument */
        for ( scan = arg ; *scan && !isspace(*scan) ; ++scan ) ;
        *scan = '\0' ;

        if ( strcmp("rem", start) != 0 ) { /* Not a comment */
          if ( strcmp("baudrate", start) == 0 ) {
            /* baudrate <int> */
            if ( !itobaud(strtol(arg, &scan, 10), &config->baudrate) ||
                 *scan != '\0' )
              error("Invalid baud rate %s in ini file %s", arg, filename) ;
          } else if ( strcmp("timeoutdelay", start) == 0 ) {
            /* timeoutdelay <int> */
            config->timeoutdelay = strtol(arg, &scan, 10) ;
            if ( *scan != '\0' )
              error("Invalid timeout %s in ini file %s", arg, filename) ;
          } else if ( strcmp("wildcards", start) == 0 ) {
            /* wildcards <bool|int> */
            if ( !strtobool(arg, &config->wildcards) )
              error("Invalid wildcards flag %s in ini file %s",
                    arg, filename) ;
          } else if ( strcmp("directories", start) == 0 ) {
            /* directories <bool|int> */
            if ( !strtobool(arg, &config->directories) )
              error("Invalid directories flag %s in ini file %s",
                    arg, filename) ;
          } else if ( strcmp("handshake", start) == 0 ) {
            /* handshake <string> */
            if ( !strtohandshake(arg, &config->handshake) )
              error("Invalid handshake type %s in ini file %s",
                    arg, filename) ;
          } else if ( strcmp("comport", start) == 0 ) {
            /* comport <string> */
            if ( (config->comport = strdup(arg)) == NULL )
              error("Out of memory storing comport %s in ini file %s",
                    arg, filename) ;
          } else if ( strcmp("basic", start) == 0 ) {
            /* basic <string> */
            if ( (config->basic = strdup(arg)) == NULL )
              error("Out of memory storing BASIC filename %s in ini file %s",
                    arg, filename) ;
          } else {
            error("Bad option in init file %s: %s %s", filename, start, arg) ;
          }
        }
      }

      fclose(dotxfer) ;
    }
  }
}

/****************************************************************************/

static struct termios oldtty ;

/* Keyboard manipulation functions */
void keyboard_open(void)
{
  int fd = fileno(stdin) ;
  struct termios newtty ;

  /* Save old tty attributes, remove ICANON processing */
  tcgetattr(fd, &oldtty) ;
  tcgetattr(fd, &newtty) ;

  newtty.c_lflag = ~(ICANON|ECHO|PENDIN) ;
  newtty.c_cc[VTIME] = 0 ; /* No timeout */
  newtty.c_cc[VMIN] = 1 ;  /* Need one character */

  (void)tcsetattr(fd, TCSANOW, &newtty) ;
}

char keyboard_char(void)
{
  return (char)getchar() ;
}

int keyboard_line(char *buffer, int size)
{
  int fd = fileno(stdin) ;
  struct termios tty ;

  /* Save current attributes, restore original attributes */
  (void)tcgetattr(fd, &tty) ;
  (void)tcsetattr(fd, TCSANOW, &oldtty) ;

  if ( fgets(buffer, size, stdin) ) {
    if ( (size = strlen(buffer)) > 0 ) {
      while ( size && buffer[size - 1] == '\n' )
        buffer[--size] = '\0' ;
    }
  } else {
    size = 0 ;
  }

  /* Set TTY to CBREAK mode */
  (void)tcsetattr(fd, TCSANOW, &tty) ;

  return size ;
}

/* Reset TTY from CBREAK mode */
void keyboard_close(void)
{
  int fd = fileno(stdin) ;

  (void)tcsetattr(fd, TCSANOW, &oldtty) ;
}

/****************************************************************************/

/* Interrupt handling */
static bool interrupt_flag = false ;

static void interrupt_signal(int value)
{
  interrupt_flag = true ;
  signal(SIGINT, interrupt_signal) ;
}

void interrupt_catch(void)
{
  signal(SIGINT, interrupt_signal) ;
}

bool interrupted(bool reset)
{
  bool result = interrupt_flag ;

  if ( reset )
    interrupt_flag = false ;

  return result ;
}

/****************************************************************************/

bool forallfiles(char *pattern, bool (*fn)(char *filename, void *data),
                 void *data)
{
  bool result = true ;
  DIR *dir ;

  if ( (dir = opendir(".")) != NULL ) {
    struct dirent *entry ;

    while ( (entry = readdir(dir)) != NULL ) {
      if ( match(pattern, entry->d_name) && !(*fn)(entry->d_name, data) ) {
        result = false ;
        break ;
      }
    }

    closedir(dir) ;
  }

  return result ;
}

/*
 * $Log: linux.c,v $
 * Revision 1.7  1999/11/08 09:38:34  angus
 * Urgh. Revolting changes to get send file to avoid buffer overruns. Sending at
 * slow speed may be the only way to prevent this...
 *
 * Revision 1.6  1999/11/06 23:04:20  angus
 * Add local and remote checksums, correct messages, quit from disc image
 * retrieve, subroutines for filespecs, dot file fixes.
 *
 * Revision 1.5  1999/11/05 02:43:05  angus
 * Linux changes; timeouts for serial read, keyboard open/close, directory
 * searching for send file.
 *
 * Revision 1.4  1999/11/04 09:21:16  angus
 * Many more changes. Altered some protocols, added text files, renumber script,
 * rewrite machine code, add track return, send file, match files, etc.
 *
 * Revision 1.3  1999/11/02 08:36:46  angus
 * Many updates; Win32 keyboard/console/serial interface, serial transfer, info
 * file read and save.
 *
 * Revision 1.2  1999/10/27 07:01:11  angus
 * Add main.c and first.c, split first-time transfer, parameter
 * encapsulation, initial configuration, argument parsing
 *
 * Revision 1.1.1.1  1999/10/25 16:51:23  angus
 * Development CVS import
 *
 */
#endif /* LINUX */
