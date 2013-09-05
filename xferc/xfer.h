#ifndef _XFER_H_
#define _XFER_H_
/* $Id: xfer.h,v 1.9 1999/11/08 09:42:48 angus Exp $
 *
 * Interface between main program and serial routines for XFer in C
 *
 * Copyright (C) Mark de Weger 1997, Angus Duggan 1999
 *
 * Freely redistributable software. See file LICENSE for details.
 */

/* Version of XFer in C. Initial version is 4.0 to distinguish from original
   XFer, which reached version 3.0 */
#define XFER_VERSION 4.0

#include <stdarg.h>
#ifdef WIN32
#include <direct.h>
#define mkdir(_p, _m) _mkdir(_p)
#define chdir(_p) _chdir(_p)
#define getcwd(_p, _l) _getcwd(_p, _l)
extern void sleep(int seconds) ;
#else
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <unistd.h> /* getcwd, chdir, mkdir */
#endif

#define RESTART_LINE "PROCmain"
#define TEXT_SYNC    "-----BBC-----PC-----"
#define TEXT_SYNC_LEN 20
#define ERR_TXT      "-----BBCerror1-----PC-----"
#define ERR_TXT_LEN 26
#define ERR_TXT2     "-----BBCerror2-----PC-----"
#define ERR_TXT2_LEN 26

#define MAXLINELEN 256    /* Max length for BBC commands, BBC/PC filenames */
#define BBCTRACKSIZE 2560 /* Number of bytes in a standard BBC track */
#define SENDBUFSIZE 4096  /* This *must* match bufsize% in xfer.bas */

/* Protocol will be incremented if there are changes in the protocol which
   required a change at the BBC end. The initial value is chosen to be higher
   than any baud rate that the BBC supports, to distinguish it from older
   versions of the XFer basic program. */
#define XFER_PROTOCOL_VERSION 100001

void error(char *format, ...) ;

typedef enum {false, true} bool ;

typedef enum {
  XFER_B1200, XFER_B2400, XFER_B4800, XFER_B9600, XFER_B19200, N_BAUD_RATES
} baud_rate_t ;

/* Handshake methods. Only DSR/DTR is currently supported. */
typedef enum {
  HANDSHAKE_XON_XOFF, HANDSHAKE_CTS_RTS, HANDSHAKE_DSR_DTR
} handshake_t ;

typedef struct { int dummy ; } *serial_h ;
typedef struct { int dummy ; } *dir_h ;

typedef enum {
  SERIAL_OK, SERIAL_TIMEOUT, SERIAL_ERROR
} serial_status_t ;

typedef enum {
  BBC_OK, BBC_ERROR, BBC_ERROR_2, BBC_SYNC
} bbc_status_t ;

typedef struct {
  char *comport, *basic ;
  bool wildcards, directories ;
  baud_rate_t baudrate ;
  handshake_t handshake ;
  int timeoutdelay ;
} configuration_t ;

/* Serial port management */
serial_status_t serial_open(configuration_t *config, serial_h *connection) ;
serial_status_t serial_config(serial_h connection, configuration_t *config) ;
serial_status_t serial_write(serial_h connection, char *buffer, int size) ;
serial_status_t serial_flush(serial_h connection) ;
serial_status_t serial_read(serial_h connection, char *buffer, int *size) ;
void serial_close(serial_h connection) ;

/* Formatted serial transfer routine with error handling */
void serial_printf(serial_h connection, char *format, ...) ;

/* Line and block-reading functions */
bbc_status_t bbc_readline(serial_h connection, char *buffer, int size) ;
bbc_status_t bbc_read(serial_h connection, char *buffer, int *size) ;

/* Directory searching */
bool forallfiles(char *pattern, bool (*fn)(char *filename, void *data),
                 void *data) ;

/* Configuration management */
void default_configuration(configuration_t *config) ;

/* First time connection functions */
bool first_time_ready(void) ;
bool first_time_send(serial_h com, char *file, bool autorun) ;

/* Utility functions */
bool itobaud(int baud, baud_rate_t *value) ;
int baudtoi(baud_rate_t value) ;
bool strtobool(char *str, bool *value) ;
bool strtohandshake(char *str, handshake_t *value) ;
bool match(char *pattern, char *string) ;

/* Transfer dialogue */
void xfer(serial_h com, configuration_t *config) ;

/* Keyboard control */
void keyboard_open(void) ;
char keyboard_char(void) ;
int keyboard_line(char *buffer, int size) ;
void keyboard_close(void) ;

/* Interrupt handling */
void interrupt_catch(void) ;
bool interrupted(bool reset) ;

/*
 * $Log: xfer.h,v $
 * Revision 1.9  1999/11/08 09:42:48  angus
 * Win32 interface for sleep()
 *
 * Revision 1.8  1999/11/08 09:38:34  angus
 * Urgh. Revolting changes to get send file to avoid buffer overruns. Sending at
 * slow speed may be the only way to prevent this...
 *
 * Revision 1.7  1999/11/07 23:32:55  angus
 * Allow quitting before connected
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
#endif /* _XFER_H_ */
