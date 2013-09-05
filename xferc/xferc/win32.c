#ifdef WIN32
/* $Id: win32.c,v 1.6 1999/11/08 09:42:48 angus Exp $
 *
 * Win32 routines for XFer in C
 *
 * Copyright (C) Mark de Weger 1997, Angus Duggan 1999
 *
 * Freely redistributable software. See file LICENSE for details.
 */

#include "xfer.h"
#include <stdio.h>
#include <stdlib.h>
#include <windows.h>


/* Utility functions for Win32 XFer */

void sleep(int seconds)
{
  Sleep(seconds * 1000) ;
}

static char *GetLastErrorMessage(void)
{
  DWORD err = GetLastError() ;
  DWORD dwRet;
  char *string = NULL ;

  static char *longest = NULL ;

  dwRet = FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER|
			FORMAT_MESSAGE_FROM_SYSTEM,
			NULL,
			err,
			LANG_NEUTRAL,
			(LPTSTR)&string,
			0,
			NULL);

  /* Save longest buffer to copy results into */
  if ( dwRet == 0 ) {      /* No error string; what to do? */
    static char message[64] ;

    sprintf(message, "error %d (%x)", err, err) ;
    return message ;
  } else if ( longest == NULL ) {
    longest = string ;
  } else if ( dwRet > strlen(longest) ) {
    LocalFree((HLOCAL)longest) ;
    longest = string ;
  } else {
    strcpy(longest, string) ;
    LocalFree((HLOCAL)string);
  }

  return longest ;
}

/****************************************************************************/

/* Serial control functions */
serial_status_t serial_open(configuration_t *config, serial_h *connection)
{
  HANDLE hComm ;
  configuration_t lconfig = *config ;

  hComm = CreateFile(lconfig.comport,
                     GENERIC_READ | GENERIC_WRITE, 
                     0, 
                     0, 
                     OPEN_EXISTING,
                     0, /* File flags */
                     0);

  if (hComm == INVALID_HANDLE_VALUE)
    return SERIAL_ERROR ;

  if ( !SetCommMask(hComm, EV_TXEMPTY) ) {
    printf("Can't set communications mask\n") ;
  }

  *connection = (serial_h)hComm ;

  lconfig.baudrate = XFER_B1200 ;

  return serial_config((serial_h)hComm, &lconfig) ;
}

serial_status_t serial_config(serial_h connection, configuration_t *config)
{
  DCB dcb ;
  COMMTIMEOUTS timeouts ;

  static DWORD dcb_rates[N_BAUD_RATES] = {
    CBR_1200, CBR_2400, CBR_4800, CBR_9600, CBR_19200
  } ;

  memset(&dcb, 0, sizeof(dcb)) ;
  memset(&timeouts, 0, sizeof(timeouts)) ;

  if ( !GetCommState((HANDLE)connection, &dcb) ||
       !GetCommTimeouts((HANDLE)connection, &timeouts) )
    return SERIAL_ERROR ;

  dcb.BaudRate = dcb_rates[config->baudrate] ;
  dcb.fBinary = 0;           /* binary mode, no EOF check */
  dcb.fParity = 0;           /* enable parity checking */
  dcb.fOutxCtsFlow = 0;      /* CTS output flow control */
  dcb.fOutxDsrFlow = 1;      /* DSR output flow control */
  dcb.fDtrControl = DTR_CONTROL_HANDSHAKE;       /* DTR flow control type */
  dcb.fDsrSensitivity = 0;     /* DSR sensitivity */
  dcb.fTXContinueOnXoff = 0; /* XOFF continues Tx */
  dcb.fOutX = 0;             /* XON/XOFF out flow control */
  dcb.fInX = 0;              /* XON/XOFF in flow control */
  dcb.fErrorChar = 0;        /* enable error replacement */
  dcb.fNull = 0;             /* enable null stripping */
  dcb.fRtsControl = RTS_CONTROL_DISABLE;       /* RTS flow control */
  dcb.fAbortOnError = 1;     /* abort reads/writes on error */
  dcb.ByteSize = 8;          /* number of bits/byte, 4-8 */
  dcb.Parity = 0;            /* 0-4=no,odd,even,mark,space */
  dcb.StopBits = 0;          /* 0,1,2 = 1, 1.5, 2 */

  /* 1200 baud = ~120 chars/sec. One line (256 bytes) should take ~2s. */
  timeouts.ReadIntervalTimeout = 1000 ;
  timeouts.ReadTotalTimeoutConstant = config->timeoutdelay * 10 ;
  timeouts.ReadTotalTimeoutMultiplier = 0 ;
  timeouts.WriteTotalTimeoutConstant = config->timeoutdelay * 10 ;
  timeouts.WriteTotalTimeoutMultiplier = 0 ;

  if ( !SetCommState((HANDLE)connection, &dcb) ||
       !SetCommTimeouts((HANDLE)connection, &timeouts) )
    return SERIAL_ERROR ;

  return SERIAL_OK ;
}

serial_status_t serial_write(serial_h connection, char *buffer, long size)
{
  while ( size > 0 ) {
    DWORD wbytes ;

    if ( !WriteFile((HANDLE)connection, buffer, (DWORD)size, &wbytes, NULL) )
      return SERIAL_ERROR ;

    buffer += wbytes ;
    size -= wbytes ;
  }

  return SERIAL_OK ;
}

serial_status_t serial_flush(serial_h connection)
{
  DWORD events = EV_TXEMPTY ;

  /* This is frustrating. Both of the calls below should wait until the
     transmit buffer, according to the documentation. However, neither
     appears to work. This is typical of Windows and NT. So instead, we
     put a sleep in to allow the buffer to drain. */
  Sleep(1000) ;

  if ( !FlushFileBuffers((HANDLE)connection) ||
       !WaitCommEvent((HANDLE)connection, &events, NULL) ) {
    COMSTAT cstat ;
    DWORD errs ;

    if ( ClearCommError((HANDLE)connection, &errs, &cstat) ) {
      printf("DSR %d CTS %d RLSD %d TXOFF %d XOFF %d EOF %d RXQ %d TXQ %d\n"
             "ERRS %x\n",
             cstat.fCtsHold, cstat.fDsrHold,
             cstat.fRlsdHold, cstat.fXoffHold,
             cstat.fXoffSent, cstat.fEof,
             cstat.cbInQue, cstat.cbOutQue,
             errs) ;
    }

    return SERIAL_ERROR ;
  }

  return SERIAL_OK ;
}

serial_status_t serial_read(serial_h connection, char *buffer, long *size)
{
  DWORD rbytes ;

  if ( !ReadFile((HANDLE)connection, buffer, (DWORD)*size, &rbytes, NULL)) {
    COMSTAT cstat ;
    DWORD errs ;

    printf("Read error %d %s\n", GetLastError(), GetLastErrorMessage()) ;
    if ( ClearCommError((HANDLE)connection, &errs, &cstat) ) {
      printf("DSR %d CTS %d RLSD %d TXOFF %d XOFF %d EOF %d RXQ %d TXQ %d\n"
             "ERRS %x\n"
             "rbytes %d\n",
             cstat.fCtsHold, cstat.fDsrHold,
             cstat.fRlsdHold, cstat.fXoffHold,
             cstat.fXoffSent, cstat.fEof,
             cstat.cbInQue, cstat.cbOutQue,
             errs, rbytes) ;
    }

    return SERIAL_ERROR ;
  }

  if ( rbytes == 0 )
    return SERIAL_TIMEOUT ;

  *size = (long)rbytes ;

  return SERIAL_OK ;
}

void serial_close(serial_h connection)
{
  CloseHandle((HANDLE)connection) ;
}

/****************************************************************************/

/* Default and user configuration */
void default_configuration(configuration_t *config)
{
  char *scan, buffer[MAXLINELEN] ;

#define GETINISTRING(key, value) \
  GetPrivateProfileString("XFer", (key), (value), buffer, MAXLINELEN, "XFer.ini")

  if ( GETINISTRING("comport", "com1:") ) {
    if ( (config->comport = strdup(buffer)) == NULL )
      error("Out of memory storing comport %s in ini file", buffer) ;
  } else /* comport must be set, regardless whether from profile or not */
    config->comport = "com1:" ;

  if ( GETINISTRING("baudrate", "") ) {
    if ( !itobaud(strtol(buffer, &scan, 10), &config->baudrate) || *scan != '\0' )
      error("Invalid baud rate %s in ini file", buffer) ;
  }

  if ( GETINISTRING("timeoutdelay", "") ) {
    config->timeoutdelay = strtol(buffer, &scan, 10) ;
    if ( *scan != '\0' )
      error("Invalid timeout %s in ini file", buffer) ;
  }

  if ( GETINISTRING("wildcards", "") ) {
    if ( !strtobool(buffer, &config->wildcards) )
      error("Invalid wildcards flag %s in ini file", buffer) ;
  }

  if ( GETINISTRING("directories", "") ) {
    if ( !strtobool(buffer, &config->directories) )
      error("Invalid directories flag %s in ini file", buffer) ;
  }

  if ( GETINISTRING("handshake", "") ) {
    if ( !strtohandshake(buffer, &config->handshake) )
      error("Invalid handshake type %s in ini file", buffer) ;
  }

  if ( GETINISTRING("basic", "") ) {
    if ( (config->basic = strdup(buffer)) == NULL )
      error("Out of memory storing basic filename %s in ini file", buffer) ;
  }
}

/****************************************************************************/

/* Keyboard manipulation functions */
static HANDLE conin ;

void keyboard_open(void)
{
  conin = GetStdHandle(STD_INPUT_HANDLE) ;

  if ( conin == NULL )
    error("Can't open console") ;
    
  if ( !SetConsoleMode(conin, ENABLE_PROCESSED_INPUT) )
    error("Can't set console mode on open (chars)") ;
}

char keyboard_char(void)
{
  char buffer[1] ;
  DWORD rbytes ;

  if ( !ReadConsole(conin, buffer, 1, &rbytes, NULL) || rbytes != 1 )
    error("Can't read character from console") ;

  if ( buffer[0] == '\r' )
    buffer[0] = '\n' ;

  return buffer[0] ;
}

long keyboard_line(char *buffer, long size)
{
  DWORD rbytes ;

  if ( !SetConsoleMode(conin, ENABLE_LINE_INPUT|ENABLE_PROCESSED_INPUT|ENABLE_ECHO_INPUT) )
    error("Can't set console mode (line)") ;
  if ( !ReadConsole(conin, buffer, size, &rbytes, NULL) )
    error("Can't read line from console") ;
  if ( !SetConsoleMode(conin, ENABLE_PROCESSED_INPUT) )
    error("Can't set console mode for line (chars)") ;

  do {
    buffer[rbytes--] = '\0' ;
  } while ( rbytes >= 0 && (buffer[rbytes] == '\n' || buffer[rbytes] == '\r') ) ;

  return rbytes + 1 ;
}

void keyboard_close(void)
{
  (void)SetConsoleMode(conin, ENABLE_LINE_INPUT|ENABLE_PROCESSED_INPUT|ENABLE_ECHO_INPUT)  ;
}

/****************************************************************************/

/* Interrupt handling */
static bool interrupt_flag = false ;

static BOOL WINAPI ControlHandler(DWORD dwCtrlType)
{
  switch( dwCtrlType ) {
  case CTRL_BREAK_EVENT:
  case CTRL_C_EVENT:
    interrupt_flag = true ;
    return TRUE;
  }
  return FALSE;
}

void interrupt_catch(void)
{
  SetConsoleCtrlHandler(ControlHandler, TRUE) ;
}

bool interrupted(bool reset)
{
  bool result = interrupt_flag ;

  if ( reset )
    interrupt_flag = false ;

  return result ;
}

/****************************************************************************/

/* Directory searching. Use match routine to make matching same between Win32
   and Linux. */
bool forallfiles(char *pattern, bool (*fn)(char *filename, void *data),
                 void *data)
{
  WIN32_FIND_DATA fdata ;
  HANDLE findh ;
  bool result = true ;

  if ( (findh = FindFirstFile("*.inf", &fdata)) != INVALID_HANDLE_VALUE ) {
    do {
      if ( match(pattern, fdata.cFileName) && !(*fn)(fdata.cFileName, data) ) {
        result = false ;
        break ;
      }
    } while ( FindNextFile(findh, &fdata) ) ;
    if ( GetLastError() != ERROR_NO_MORE_FILES )
      result = false ;
    FindClose(findh) ;
  } else
    result = false ;

  return result ;
}

/*
 * $Log: win32.c,v $
 * Revision 1.6  1999/11/08 09:42:48  angus
 * Win32 interface for sleep()
 *
 * Revision 1.5  1999/11/04 19:05:48  angus
 * Add configuration entry for BASIC program filename
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
#endif /* WIN32 */
