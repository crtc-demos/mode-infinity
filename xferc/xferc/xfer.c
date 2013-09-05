/* $Id: xfer.c,v 1.10 1999/11/08 09:38:34 angus Exp $
 *
 * Transfer dialogue routines for XFer in C
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

/*****************************************************************************/

/* BBC filename structure and definitions */

/* File attribute flags */
enum { FILE_Not_R = 1, FILE_Not_W = 2, FILE_Not_X = 4, FILE_Not_D = 8,
       FILE_Not_R_Others = 16, FILE_Not_W_Others = 32,
       FILE_Not_X_Others = 64, FILE_Not_D_Others = 128 } ;

/* Return accumulator values of OSFILE 6 */
enum { FILE_none = 0, FILE_file = 1, FILE_directory = 2 } ;

typedef struct _filelist {
  char name[MAXLINELEN] ;
  unsigned long load, exec, length, attrs ;
  int type ;
  struct _filelist *next ;
} filelist ;

/* Auxiliary functions for file retrieval and sending */

/* Combine buffer characters into CRC. We use a 32-bit checksum based around
   the primitive polynomial x^32 + x^7 + x^5 + x^3 + x^2 + x + 1. */
static void crccalc(unsigned char *buffer, long len, unsigned long *crc)
{
  unsigned long value = *crc ;

  while ( len-- > 0 ) {
    int i ;

    value ^= *buffer++ << 24 ;

    for ( i = 0 ; i < 8 ; ++i ) {
      if ( value & 0x80000000 )
        value = (value << 1) ^ 0xaf ;
      else
        value <<= 1 ;
    }
    value &= 0xffffffff ; /* In case of 64-bit longs */
  }

  *crc = value ;
}

/* Match string without globs, but with ? wildcards */
static bool qmatch(char *pattern, char *string, int left)
{
  while ( *pattern && *string && left-- ) {
    if ( tolower(*pattern) != tolower(*string) && *pattern != '?' )
      return false ;
    ++pattern, ++string ;
  }

  return *pattern == *string ;
}

bool match(char *pattern, char *string)
{
  char *star = strchr(pattern, '*') ;

  if ( star == NULL )	/* No globs, must match exactly */
    return qmatch(pattern, string, -1) ;

  if ( star != pattern ) { /* match and remove stuff before star */
    if ( !qmatch(pattern, string, star - pattern) )
      return false ;
    string += star - pattern ;
  }

  while (*star == '*') ++star ;	/* find char after star */

  if ( *star != '\0' ) {  /* loop searching for thing after star */
    while ( (string = strchr(string, *star)) != NULL ) {
      if ( match(star, string) )
	return true ;
      ++string ;	/* skip over initial match char */
    }

    return false ;
  }

  /* Nothing after star, so it must match */
  return true ;
}

static bbc_status_t getcurdir(serial_h com, char *buffer, long size)
{
  serial_printf(com, "C") ;

  return bbc_readline(com, buffer, size) ;
}

static bbc_status_t getbootopt(serial_h com, char *buffer, long size)
{
  serial_printf(com, "B") ;

  return bbc_readline(com, buffer, size) ;
}

static bbc_status_t setbootopt(serial_h com, int opt4)
{
  char waste[MAXLINELEN] ;

  serial_printf(com, "F%d\r", opt4) ;

  return bbc_readline(com, waste, MAXLINELEN) ;
}

static bbc_status_t setcurdir(serial_h com, char *buffer)
{
  bbc_status_t result ;

  serial_printf(com, "*DIR %s\r", buffer) ;

  do {
    char waste[MAXLINELEN] ;

    result = bbc_readline(com, waste, MAXLINELEN) ;
  } while ( result == BBC_OK ) ;

  return result ;
}

/* Get file information from BBC using OSFILE. Filelist structure is updated
   with information. */
static bbc_status_t getfileinfo(serial_h com, filelist *file)
{
  bbc_status_t result ;
  char buffer[MAXLINELEN] ;

  serial_printf(com, "I%s\r", file->name) ;

  if ( (result = bbc_readline(com, buffer, MAXLINELEN)) == BBC_OK ) {
    if ( sscanf(buffer, "%s %lx %lx %lx %lx %d", file->name,
                &file->load, &file->exec, &file->length, &file->attrs,
                &file->type) != 6 ) {
      printf("INFO returned does not match expected format: %s\n", buffer) ;
    }
  } else
    printf("INFO did not return expected result\n") ;

  return result ;
}

/* Get file names from BBC which match pattern, and create linked list of
   file information. *INFO is used to get the filenames, because OSGBPB 8
   only returns files in current directory, and there is no easy way of 
   finding all of the DFS/DNFS single-character directories. If the
   directories argument is true, then all single character directories will
   be listed using "*INFO *.*", otherwise "*INFO *" will be used. Pattern
   can contain * and ? to match strings or characters. */
static bbc_status_t getfilenames(serial_h com, char *pattern, filelist **names,
                                 bool directories)
{
  char buffer[MAXLINELEN] ;
  bbc_status_t result ;
  int nnames = 0 ;

  /* If we allow directories, check that its not a multi-format DFS which
     is in a subdirectory */
  if ( directories ) {
    if ( (result = getcurdir(com, buffer, MAXLINELEN)) != BBC_OK )
      return result ;
    if ( strlen(buffer) != 1 )
      directories = false ;
  }

  *names = NULL ;

  serial_printf(com, directories ? "*INFO *.*\r" : "*INFO *\r") ;
  while ( (result = bbc_readline(com, buffer, MAXLINELEN)) == BBC_OK ) {
    char *start, *end ;

    for ( start = buffer ; *start && isspace(*start) ; ++start) ;
    for ( end = start ; *end && !isspace(*end) ; ++end) ;

    if ( start == end ) {
      printf("Empty name returned by *INFO, skipping %s\n", buffer) ;
      continue ;
    }

    *end = '\0' ;

    if ( !match(pattern, start) ) /* Doesn't match pattern */
      continue ;

    if ( (*names = (filelist *)malloc(sizeof(filelist))) == NULL )
      error("Out of memory storing file info for %s", start) ;

    strcpy((*names)->name, start) ;
    (*names)->next = NULL ;
    names = &(*names)->next ;
    ++nnames ;
  }

  return result ;
}

/* Test if PC filename is used. If it is used, offer to rename or skip, and
   test new name. Returns false if skip was selected, true if OK. */
static bool check_pcname(char *type, char *pcname, long size)
{
  FILE *pcfile ;

  while ( (pcfile = fopen(pcname, "rb")) != NULL ) {
    char ch ;

    fclose(pcfile) ;

    printf("%s %s exists on PC. Continue/Rename/Skip? (C/R/S) ", type, pcname) ;
    do {
      ch = toupper(keyboard_char()) ;
    } while ( strchr("CRS", ch) == NULL ) ;

    putchar(ch) ;
    putchar('\n') ;

    if ( ch == 'S' ) /* Skip file */
      return false ;

    if ( ch == 'C' ) /* Continue with this name */
      break ;

    if ( ch == 'R' ) { /* Rename PC file */
      long len ;

      do {
        printf("Enter new PC file name: ") ;
        len = keyboard_line(pcname, size) ;
      } while ( len == 0 ) ;
    }
  }

  return true ;
}

/* Get a valid BBC filespec */
static long filespec(char *buffer, long size, bool wildcards, bool directories)
{
  char localbuf[MAXLINELEN + 1], *name = localbuf + 1 ;
  long len ;

  printf("File spec (* and ? %sallowed): ", wildcards ? "" : "not ") ;

  if ( (len = keyboard_line(name, MAXLINELEN)) == 0 ) {
    puts("No file spec supplied") ;
    return 0 ;
  }

  if ( name[0] == ':' ) {
    puts("Drive specification not allowed") ;
    return 0 ;
  }

  if ( name[0] == '.' ) { /* Add space to front */
    *--name = ' ' ;
    ++len ;
  }

  if ( !wildcards &&
       (strchr(name, '*') != NULL || strchr(name, '?') != NULL) ) {
    puts("Wildcards not allowed in file spec") ;
    return 0 ;
  }

  if ( strchr(name, '#') != NULL ) {
    puts("# wildcard not allowed, please use ? instead") ;
    return 0 ;
  }

  if ( !directories && strchr(name, '.') != NULL ) {
    puts("Directories not allowed in file spec") ;
    return 0 ;
  }

  if ( len >= size ) {
    puts("File name too long") ;
    return 0 ;
  }

  strcpy(buffer, name) ;

  return len ;
}

/*****************************************************************************/

/* Retrieving files from BBC */

static bbc_status_t retrieve_file(serial_h com, filelist *file)
{
  bbc_status_t result ;

  file->type = 0 ;

  if ( (result = getfileinfo(com, file)) == BBC_OK ) {
    char pcname[MAXLINELEN] ;
    FILE *pcfile ;
    bool fileerr = false ;

    if ( file->type == 0 ) { /* OSFILE returned 0 */
      printf("File %s does not exist on BBC, skipping\n", file->name) ;
      return BBC_OK ;
    }

    strcpy(pcname, file->name) ;

    /* Check if PC name is used */
    if ( !check_pcname(file->type == 2 ? "Directory" : "File",
                       pcname, MAXLINELEN) )
      return BBC_OK ;

    if ( file->type == 1 ) { /* OSFILE indicates it's a file */
      char buffer[BBCTRACKSIZE] ;
      long fhandle, size ;

      if ( (pcfile = fopen(pcname, "wb")) == NULL ) {
        printf("Can't open PC file %s to retrieve %s, skipping\n",
               pcname, file->name) ;
        return BBC_OK ;
      }

      printf("Retrieving file %s %lx %lx %lx %c%c%c%c to %s\n",
             file->name, file->load, file->exec, file->length,
             (file->attrs & FILE_Not_R) ? ' ' : 'R',
             (file->attrs & FILE_Not_W) ? ' ' : 'W',
             (file->attrs & FILE_Not_X) ? ' ' : 'X',
             (file->attrs & FILE_Not_D) ? 'L' : ' ',
             pcname) ;

      serial_printf(com, "S%s\r", file->name) ;

      if ( (result = bbc_readline(com, buffer, MAXLINELEN)) == BBC_SYNC &&
           (result = bbc_readline(com, buffer, MAXLINELEN)) == BBC_OK &&
           sscanf(buffer, "%ld", &fhandle) == 1 &&
           fhandle != 0 &&
           (result = bbc_readline(com, buffer, MAXLINELEN)) == BBC_OK &&
           sscanf(buffer, "%ld", &size) == 1 ) {
        long crc = 0, remaining = size, nbytes = 0 ;

        while ( remaining > 0 ) {
          long rbytes = remaining > BBCTRACKSIZE ? BBCTRACKSIZE : remaining ;

          if ( (result = bbc_read(com, buffer, &rbytes)) == BBC_OK ) {
            if ( !fileerr &&
                 (long)fwrite(buffer, sizeof(char), rbytes, pcfile) != rbytes )
              fileerr = true ;
            remaining -= rbytes ;
            nbytes += rbytes ;
            crccalc(buffer, rbytes, &crc) ;
            printf("\rRead %ld bytes of %ld", nbytes, size) ;
            fflush(stdout) ;
          } else /* Error reading bytes */
            break ;
        }

        putchar('\n') ;

        if ( result == BBC_OK ) {
          long bbccrc = 0 ;

          if ( (result = bbc_readline(com, buffer, MAXLINELEN)) != BBC_OK ||
               sscanf(buffer, "%ld", &bbccrc) != 1 ) {
            printf("Problem retrieving CRC for %s from BBC\n", file->name) ;
            fileerr = true ;
          } else if ( bbccrc != crc ) {
            printf("CRC error for %s (%lx not equal to %lx)\n",
                   file->name, crc, bbccrc) ;
            fileerr = true ;
          }
        }
      } else {
        printf("Problem opening %s on BBC, skipping\n", file->name) ;
        fileerr = true ;
      }

      fclose(pcfile) ;
    } else if ( file->type == 2 ) { /* OSFILE indicates it's a directory */
      char pcdir[MAXLINELEN], bbcdir[MAXLINELEN] ;
      filelist *subfiles = NULL ;

      printf("Retrieving directory %s %lx %lx %lx %c%c%c%c to %s\n",
             file->name, file->load, file->exec, file->length,
             (file->attrs & FILE_Not_R) ? ' ' : 'R',
             (file->attrs & FILE_Not_W) ? ' ' : 'W',
             (file->attrs & FILE_Not_X) ? ' ' : 'X',
             (file->attrs & FILE_Not_D) ? 'L' : ' ',
             pcname) ;
      (void)mkdir(pcname, 0755) ;
      if ( getcwd(pcdir, MAXLINELEN) &&
           (result = getcurdir(com, bbcdir, MAXLINELEN)) == BBC_OK ) {
        if ( chdir(pcname) == 0 ) {
          if ( (result = setcurdir(com, file->name)) == BBC_SYNC ) {
            if ( (result = getfilenames(com, "*", &subfiles, false)) == BBC_SYNC ) {
              result = BBC_OK ;

              while ( subfiles && !interrupted(false) ) {
                filelist *next = subfiles->next ;

                if ( (result = retrieve_file(com, subfiles)) != BBC_OK ) {
                  printf("Error retrieving file %s, skipping\n",
                         subfiles->name) ;
                  free(subfiles) ;
                  subfiles = next ;
                  fileerr = true ;
                  break ;
                }

                free(subfiles) ;
                subfiles = next ;
              }

              while ( subfiles ) {
                filelist *next = subfiles->next ;
                printf("Skipping file %s because of previous error\n",
                       subfiles->name) ;
                free(subfiles) ;
                subfiles = next ;
              }

              if ( interrupted(true) )
                fileerr = true ;
            }

            if ( result == BBC_OK &&
                 (result = setcurdir(com, bbcdir)) == BBC_SYNC )
              result = BBC_OK ;
          }
          (void)chdir(pcdir) ;
        }
      }
    } else {
      printf("File %s has unknown OSFILE type %d, skipping\n",
             file->name, file->type) ;
      return BBC_OK ;
    }

    if ( result == BBC_OK && !fileerr ) { /* Write .inf file */
      char *basename ;

      strcat(pcname, ".inf") ;

      /* Get basename to compare against; if !boot, get boot option */
      if ( (basename = strrchr(file->name, '.')) != NULL )
        ++basename ;
      else
        basename = file->name ;

      if ( (pcfile = fopen(pcname, "w")) != NULL ) {
        fprintf(pcfile, "%s %06lx %06lx %06lx%s",
                file->name, file->load, file->exec, file->length,
                (file->attrs & FILE_Not_D) ? " Locked" : "") ;
        /* Use qmatch to use case-insensitive comparison */
        if ( qmatch("!boot", basename, -1) ) {
          char buffer[MAXLINELEN] ;

          if ( (result = getbootopt(com, buffer, MAXLINELEN)) == BBC_OK )
            fprintf(pcfile, " OPT4=%s", buffer) ;
        }
        fprintf(pcfile, " ATTR=%lx TYPE=%d\n", file->attrs, file->type) ;
        fclose(pcfile) ;
      } else { /* Can't open .inf name, delete downloaded file */
        printf("Problem creating info file %s.inf, skipping\n", file->name) ;
        pcname[strlen(pcname) - 4] = '\0' ;
        remove(pcname) ;
      }
    } else { /* If download failed, remove file */
      remove(pcname) ;
    }
  }

  return result ;
}

static bbc_status_t retrieve_files(serial_h com, bool wildcards, bool directories)
{
  char name[MAXLINELEN] ;
  bbc_status_t result = BBC_OK ;

  if ( filespec(name, MAXLINELEN, wildcards, directories) == 0 )
    return BBC_OK ;

  if ( wildcards ) {
    filelist *files ;

    if ( (result = getfilenames(com, name, &files, directories)) == BBC_SYNC ) {
      result = BBC_OK ;

      while ( files && !interrupted(true) ) {
        filelist *next = files->next ;

        if ( (result = retrieve_file(com, files)) != BBC_OK ) {
          printf("Error retrieving file %s, skipping\n", files->name) ;
          free(files) ;
          files = next ;
          break ;
        }

        free(files) ;
        files = next ;
      }

      while ( files ) {
        filelist *next = files->next ;
        printf("Skipping file %s because of previous error\n", files->name) ;
        free(files) ;
        files = next ;
      }
    }
  } else {
    filelist file ;

    strcpy(file.name, name) ;

    if ( (result = retrieve_file(com, &file)) != BBC_OK )
      printf("Error retrieving file %s\n", name) ;
  }

  return result ;
}

/*****************************************************************************/

/* Get CRC of remote file; in conjunction with local_crc, allows checking if
   file is same at PC and BBC */

static bbc_status_t retrieve_crc(serial_h com, filelist *file)
{
  char buffer[MAXLINELEN] ;
  bbc_status_t result ;
  long fhandle, bbccrc ;

  serial_printf(com, "X%s\r", file->name) ;

  if ( (result = bbc_readline(com, buffer, MAXLINELEN)) == BBC_SYNC &&
       (result = bbc_readline(com, buffer, MAXLINELEN)) == BBC_OK &&
       sscanf(buffer, "%ld", &fhandle) == 1 &&
       fhandle != 0 &&
       (result = bbc_readline(com, buffer, MAXLINELEN)) == BBC_OK &&
       sscanf(buffer, "%ld", &bbccrc) == 1 ) {
    printf("BBC file %s has checksum %lx\n", file->name, bbccrc) ;
  }

  return result ;
}

static bbc_status_t remote_crc(serial_h com, bool wildcards, bool directories)
{
  bbc_status_t result = BBC_OK ;
  char name[MAXLINELEN] ;

  if ( filespec(name, MAXLINELEN, wildcards, directories) == 0 )
    return BBC_OK ;

  if ( wildcards ) {
    filelist *files ;

    if ( (result = getfilenames(com, name, &files, directories)) == BBC_SYNC ) {
      result = BBC_OK ;

      while ( files && !interrupted(true) ) {
        filelist *next = files->next ;

        if ( (result = retrieve_crc(com, files)) != BBC_OK ) {
          printf("Error retrieving CRC of %s, skipping\n", files->name) ;
          free(files) ;
          files = next ;
          break ;
        }

        free(files) ;
        files = next ;
      }

      while ( files ) {
        filelist *next = files->next ;
        printf("Skipping file %s because of previous error\n", files->name) ;
        free(files) ;
        files = next ;
      }
    }
  } else {
    filelist file ;

    strcpy(file.name, name) ;

    if ( (result = retrieve_crc(com, &file)) != BBC_OK )
      printf("Error retrieving CRC for %s\n", name) ;
  }

  return result ;
}

/*****************************************************************************/

/* Get CRC of local file; in conjunction with remote_crc, allows checking if
   file is same at PC and BBC */

static bool crc_file_forall(char *inffile, void *data)
{
  FILE *file ;
  char *scan, filename[MAXLINELEN], buffer[BBCTRACKSIZE] ;
  long rbytes, crc = 0 ;

  if ( (scan = strrchr(inffile, '.')) == NULL || !qmatch(".inf", scan, -1) ) {
    printf("File %s is not an INF file, skipping\n", inffile) ;
    return true ;
  }

  strncpy(filename, inffile, scan - inffile) ;
  filename[scan - inffile] = '\0' ;

  if ( (file = fopen(filename, "r")) == NULL ) {
    printf("Problem opening %s, skipping\n", filename) ;
    return true ; /* don't abort because of this */
  }

  while ( (rbytes = fread(buffer, sizeof(char), BBCTRACKSIZE, file)) > 0 )
    crccalc(buffer, rbytes, &crc) ;

  fclose(file) ;

  printf("File %s has checksum %lx\n", filename, crc) ;

  return true ;
}

static bbc_status_t local_crc(void)
{
  char buffer[MAXLINELEN] ;

  /* Get file names */
  printf("File spec (* and ? allowed): ") ;
  if ( keyboard_line(buffer, MAXLINELEN) == 0 ) {
    puts("No file spec supplied") ;
    return BBC_OK ;
  }

  strcat(buffer, ".inf") ;

  (void)forallfiles(buffer, crc_file_forall, NULL) ;

  return BBC_OK ;
}

/*****************************************************************************/

/* Retrieve a disc image */

static bbc_status_t retrieve_disc(serial_h com)
{
  char drivech, *extn = NULL, buffer[BBCTRACKSIZE], imagename[MAXLINELEN] ;
  bbc_status_t result ;
  FILE *image ;
  long size = 0, ntracks = 0 ;
  bool trackerr = false ;

  printf("Drive number (0-3, S to skip): ") ;
  do {
    drivech = toupper(keyboard_char()) ;
  } while ( strchr("0123S", drivech) == NULL ) ;

  putchar(drivech) ;
  putchar('\n') ;

  if ( drivech == 'S' )
    return BBC_OK ;

  serial_printf(com, "*DRIVE %c\r", drivech) ;
  do {
    result = bbc_readline(com, buffer, MAXLINELEN) ;
  } while ( result == BBC_OK ) ;

  if ( result != BBC_SYNC ) {
    printf("Problem setting drive %c\n", drivech) ;
    return result ;
  }

  /* Get number of sectors */
  serial_printf(com, "N") ;
  if ( (result = bbc_readline(com, buffer, MAXLINELEN)) != BBC_OK ||
       sscanf(buffer, "%ld", &size) != 1 ) {
    printf("Problem reading number of sectors on drive %c\n", drivech) ;
    return result ;
  }

  /* Decide on image type .ssd .dsd .hsd or other */
  switch ( size ) {
  case 400 * 256:
    extn = ".ssd" ;
    break ;
  case 800 * 256:
    extn = ".dsd" ;
    break ;
  case 1600 * 256:
    extn = ".hsd" ;
    break ;
  default:
    printf("Unrecognised disc format, drive %c has %ld bytes\n", drivech, size) ;
  }  

  if ( size % BBCTRACKSIZE != 0 ) {
    printf("Disc %c size returned is not a whole number of tracks\n", drivech) ;
    return BBC_OK ;
  }

  size /= BBCTRACKSIZE ;
  if ( size > 160 || (size > 80 && drivech >= '2') ) {
    printf("Disc %c has more tracks than allowed (%ld)\n", drivech, size) ;
    return BBC_OK ;
  }

  /* Get image name */
  printf("Disc image name (default extension %s): ", extn ? extn : "none") ;
  if ( keyboard_line(imagename, MAXLINELEN) == 0 ) {
    puts("No disc image name supplied") ;
    return BBC_OK ;
  }

  /* Add extension to image */
  if ( strrchr(imagename, '.') == NULL && extn != NULL )
    strcat(imagename, extn) ;

  /* Check if PC name is used */
  if ( !check_pcname("Disc image", imagename, MAXLINELEN) )
    return BBC_OK ;

  if ( (image = fopen(imagename, "wb")) == NULL ) {
    printf("Problem opening image file %s\n", imagename) ;
    return BBC_OK ;
  }

  /* Read whole disc, one track at a time */
  for ( ntracks = 0 ; !interrupted(false) && !trackerr && ntracks < size ; ++ntracks ) {
    long remaining = BBCTRACKSIZE, crc = 0 ;

    serial_printf(com, "G%c\r%d\r", drivech, ntracks) ;
    do {
      long rbytes = remaining ;

      if ( (result = bbc_read(com, buffer, &rbytes)) == BBC_OK ) {
        if ( !trackerr &&
             (long)fwrite(buffer, sizeof(char), rbytes, image) != rbytes )
          trackerr = true ;
        remaining -= rbytes ;
        crccalc(buffer, rbytes, &crc) ;
        printf("\rRead %ld tracks of %ld", ntracks + 1, size) ;
        fflush(stdout) ;
      } else /* Error reading bytes */
        break ;
    } while ( remaining > 0 ) ;

    /* Get checksum */
    if ( result == BBC_OK ) {
      long bbccrc = 0 ;

      if ( (result = bbc_readline(com, buffer, MAXLINELEN)) != BBC_OK ||
           sscanf(buffer, "%ld", &bbccrc) != 1 ) {
        printf("\nProblem retrieving CRC for disc %c track %ld from BBC\n",
               drivech, ntracks) ;
        trackerr = true ;
      } else if ( bbccrc != crc ) {
        printf("\nCRC error for disc %c track %ld from BBC\n",
               drivech, ntracks) ;
        trackerr = true ;
      }
    } else {
      printf("\nProblem retrieving disc %c track %ld from BBC\n",
             drivech, ntracks) ;
      trackerr = true ;
    }
  }

  putchar('\n') ;

  fclose(image) ;

  if ( trackerr || interrupted(true) )
    remove(imagename) ;

  return result ;
}

/*****************************************************************************/

/* Sending files to BBC */

static bbc_status_t send_file(serial_h com, char *inffile)
{
  char pcname[MAXLINELEN], bbcname[MAXLINELEN] ;
  char buffer[SENDBUFSIZE] ;
  bbc_status_t result = BBC_OK ;
  long load, exec, length, attr = 0, crc = 0 ;
  int nscan, type = 1, opt4 = -1 ;
  char *scan ;
  FILE *fileh ;
  bool fileerr = false ;

  /* Copy file without ".inf" extension */
  if ( (scan = strrchr(inffile, '.')) == NULL || !qmatch(".inf", scan, -1) ) {
    printf("File %s is not an INF file, skipping\n", inffile) ;
    return BBC_OK ;
  }

  strncpy(pcname, inffile, scan - inffile) ;
  pcname[scan - inffile] = '\0' ;

  /* Get load, exec, length information from INF file */
  if ( (fileh = fopen(inffile, "r")) == NULL ) {
    printf("Problem opening INF file %s\n", inffile) ;
    return BBC_OK ;
  }
  scan = fgets(buffer, SENDBUFSIZE, fileh) ;
  fclose(fileh) ;

  if ( scan == NULL ||
       sscanf(scan, "%s %lx %lx %lx %n", bbcname,
              &load, &exec, &length, &nscan) != 4 ) {
    printf("Problem reading attributes from INF file %s\n", inffile) ;
    return BBC_OK ;
  }

  do {
    scan += nscan ;
    while ( isspace(*scan) ) ++scan ;
    if ( strncmp(scan, "Locked", 6) == 0 ) {
      attr |= FILE_Not_D|FILE_Not_D_Others ;
      nscan = 6 ;
    } else if ( sscanf(scan, " OPT4=%d%n", &opt4, &nscan) != 1 &&
                sscanf(scan, " ATTR=%lx%n", &attr, &nscan) != 1 &&
                sscanf(scan, " TYPE=%d%n", &type, &nscan) != 1 )
      break ;
  } while ( true ) ;

  if ( type == 2 ) {
    printf("No standard BBC method of creating directories, skipping %s\n", pcname) ;
    return BBC_OK ;
  } else if ( type != 1 ) {
    printf("Cannot send unknown file %s with unknown OSFILE type %d, skipping\n",
           pcname, type) ;
    return BBC_OK ;
  }

  printf("Sending file %s %lx %lx %lx %c%c%c%c from %s\n",
         bbcname, load, exec, length,
         (attr & FILE_Not_R) ? ' ' : 'R',
         (attr & FILE_Not_W) ? ' ' : 'W',
         (attr & FILE_Not_X) ? ' ' : 'X',
         (attr & FILE_Not_D) ? 'L' : ' ',
         pcname) ;

  /* Open real file and send it */
  if ( (fileh = fopen(pcname, "rb")) == NULL ) {
    printf("Problem opening file %s\n", pcname) ;
    return BBC_OK ;
  }

  serial_printf(com, "R%s\r%d\r%d\r%d\r%d\r", bbcname,
                load, exec, length, attr) ;
  if ( (result = bbc_readline(com, buffer, MAXLINELEN)) == BBC_SYNC ) {
    long nbytes = 0, remaining = length, nwait = SENDBUFSIZE ;

    /* The send loop is revolting. I don't like using sleep(), but it seems
       unavoidable; after the BBC has got a buffer full, it saves to disc.
       While it is saving, and NMI is claimed, it cannot alter the CTS line
       fast enough to prevent buffer overruns (even experimenting with FX 203
       doesn't help. We get around this by matching buffer sizes exactly, and
       putting in a delay after sending each buffer which should be long
       enough to write the buffer to disc. We also send the buffer in small
       chunks and allow the output to drain between writes. */
    while ( nbytes < length ) {
      long wbytes = remaining > MAXLINELEN ? MAXLINELEN : remaining ;

      if ( !fileerr &&
           (long)fread(buffer, sizeof(char), wbytes, fileh) != wbytes ) {
        printf("\nError reading file %s", pcname) ;
        fileerr = true ;
      }
      switch ( serial_write(com, buffer, wbytes) ) {
      case SERIAL_ERROR:
        error("Communications failure") ;
      case SERIAL_TIMEOUT: /* Want more sensible error handling here */
        error("Connection timed out") ;
      }
      serial_flush(com) ;
      remaining -= wbytes ;
      nbytes += wbytes ;
      crccalc(buffer, wbytes, &crc) ;
      printf("\rSent %ld bytes of %ld", nbytes, length) ;
      fflush(stdout) ;
      if ( nbytes >= nwait ) {
        sleep(SENDBUFSIZE / 512) ; /* Allow 1 extra second per 1/2 K sent */
        nwait += SENDBUFSIZE ;
      } else
        sleep(1) ; /* Allow some time for drain or raise CTS */
    }

    putchar('\n') ;

    serial_printf(com, "%d\r", crc) ;
    /* Synchronise once for CRC and once for writing info to disc */
    if ( (result = bbc_readline(com, buffer, MAXLINELEN)) != BBC_SYNC ) {
      if ( result == BBC_ERROR_2 )
        printf("CRC error sending file %s\n", pcname) ;
    } else if ( (result = bbc_readline(com, buffer, MAXLINELEN)) == BBC_SYNC )
      result = BBC_OK ;
  }

  fclose(fileh) ;

  /* Set !BOOT option if sending !BOOT file */
  if ( result == BBC_OK && opt4 >= 0 )
    if ( (result = setbootopt(com, opt4)) == BBC_SYNC )
      result = BBC_OK ;

  return result ;
}

typedef struct {
  serial_h com ;
  bbc_status_t result ;
} send_forall_t ;

static bool send_file_forall(char *filename, void *data)
{
  send_forall_t *forall = data ;

  if ( (forall->result = send_file(forall->com, filename)) != BBC_OK )
    return false ;

  return true ;
}

static bbc_status_t send_files(serial_h com, bool wildcards, bool directories)
{
  char buffer[MAXLINELEN] ;
  send_forall_t forall ;

  forall.com = com ;
  forall.result = BBC_OK ;

  /* Get file names */
  printf("File spec (* and ? allowed): ") ;
  if ( keyboard_line(buffer, MAXLINELEN) == 0 ) {
    puts("No file spec supplied") ;
    return BBC_OK ;
  }

  strcat(buffer, ".inf") ;

  (void)forallfiles(buffer, send_file_forall, &forall) ;

  return forall.result ;
}

/*****************************************************************************/

/* Send an OS command line to BBC */

static bbc_status_t oscli(serial_h com, FILE *log)
{
  char buffer[MAXLINELEN] ;
  bbc_status_t result = BBC_OK ;
  
  if ( keyboard_line(buffer, MAXLINELEN) != 0 ) {
    serial_printf(com, "*%s\r", buffer) ;

    /* Read response until a SYNC or ERROR line */
    while ( (result = bbc_readline(com, buffer, MAXLINELEN)) == BBC_OK ) {
      if ( log ) {
        long len = strlen(buffer) ;
        if ( (long)fwrite(buffer, sizeof(char), len, log) != len ||
             fputc('\n', log) == EOF )
          log = NULL ;
      }
      puts(buffer) ;
    }
  }

  return result ;
}

/*****************************************************************************/

/* Emulate BBC terminal */
static bbc_status_t terminal(serial_h com)
{
  puts("Not Yet Implemented") ;
  return BBC_OK ;
}

/*****************************************************************************/

/* Main transfer dialogue routine */

void xfer(serial_h com, configuration_t *config)
{
  FILE *log = NULL ;
  int ch ;
  long linelen ;
  char buffer[MAXLINELEN] ;

  do {
    bbc_status_t result = BBC_OK ;

    printf("\f\n\n"
           "     (R)eceive files from BBC          (S)end files to BBC\n"
           "     (*)-command on BBC                (D)o command on PC\n"
           "     (T)erminal emulation              (G)et disc image from BBC\n"
           "     (L)og BBC OSCLI output %s      (C)d to directory\n"
           "     (P)C file CRC                     (B)BC file CRC\n"
           "     (Q)uit\n\n"
           "Enter command: ", log ? "(on) " : "(off)") ;

    do {
      ch = toupper(keyboard_char()) ;
    } while ( strchr("RS*DTGLCQPB", ch) == NULL ) ;

    putchar(ch) ;

    switch ( ch ) {
    case 'L':
      putchar('\n') ;
      if ( log ) {
        fclose(log) ;
        log = NULL ;
        puts("Logging turned off") ;
      } else {
        printf("Log OSCLI output to file: ") ;
        linelen = keyboard_line(buffer, MAXLINELEN) ;

        if ( linelen == 0 )
          puts("No log file specified, not logging\n") ;
        else if ( (log = fopen(buffer, "w+")) == NULL )
          printf("Problem opening log file %s, not logging\n", buffer) ;
      }

      break ;
    case 'R':
      putchar('\n') ;
      result = retrieve_files(com, config->wildcards, config->directories) ;
      break ;
    case 'S':
      putchar('\n') ;
      result = send_files(com, config->wildcards, config->directories) ;
      break ;
    case 'P':
      putchar('\n') ;
      result = local_crc() ;
      break ;
    case 'B':
      putchar('\n') ;
      result = remote_crc(com, config->wildcards, config->directories) ;
      break ;
    case '*':
      result = oscli(com, log) ;
      break ;
    case 'G':
      putchar('\n') ;
      result = retrieve_disc(com) ;
      break ;
    case 'D':
      (void)getcwd(buffer, MAXLINELEN) ;
      printf("\n%s> ", buffer) ;
      linelen = keyboard_line(buffer, MAXLINELEN) ;

      fflush(stdout) ;
      fflush(stdin) ;

      if ( linelen > 0 ) {
        keyboard_close() ;
        system(buffer) ;
        keyboard_open() ;
      }

      break ;
    case 'C':
      printf("\nDirectory: ") ;
      linelen = keyboard_line(buffer, MAXLINELEN) ;

      if ( chdir(buffer) != 0 )
        printf("Problem changing directory to %s, ignoring\n", buffer) ;

      break ;
    case 'T':
      putchar('\n') ;
      result = terminal(com) ;
      break ;
    }

    while ( result == BBC_ERROR ) {
      serial_printf(com, ERR_TXT) ;
      if ( (result = bbc_readline(com, buffer, MAXLINELEN)) == BBC_OK &&
           (result = bbc_readline(com, buffer, MAXLINELEN)) == BBC_OK )
        printf("BBC Error: %s\n", buffer) ;
    }
  } while ( ch != 'Q' ) ;

  putchar('\n') ;

  serial_printf(com, "Q") ;

  if ( log )
    fclose(log) ;
}

/*
 * $Log: xfer.c,v $
 * Revision 1.10  1999/11/08 09:38:34  angus
 * Urgh. Revolting changes to get send file to avoid buffer overruns. Sending at
 * slow speed may be the only way to prevent this...
 *
 * Revision 1.9  1999/11/08 02:08:37  angus
 * Fix disc image retrieve sectors byte, interrupt disc retrieve
 *
 * Revision 1.8  1999/11/06 23:04:20  angus
 * Add local and remote checksums, correct messages, quit from disc image
 * retrieve, subroutines for filespecs, dot file fixes.
 *
 * Revision 1.7  1999/11/05 02:44:15  angus
 * Undo debugging comment
 *
 * Revision 1.6  1999/11/05 02:43:05  angus
 * Linux changes; timeouts for serial read, keyboard open/close, directory
 * searching for send file.
 *
 * Revision 1.5  1999/11/04 10:22:41  angus
 * Bugfixes to filelength loop in assembly and setbootopt.
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
