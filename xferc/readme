********************
* XFER in C README *
********************


Why XFer?
=========

Welcome to XFer, a set of programs for the transfer of BBC files
between a PC (running Windows95/98/NT/2000 or Linux) and a BBC model B.

What's the point of using XFer instead of other programs with similar
functions?
- The main advantage of XFer is that it *does* consider the file
  attributes (load and exec addresses and locked attribute) of BBC files.
  These file attributes are usually required to get a program to run.
  Utilities like Kermit do not transfer these attributes. Therefore, if
  you transfer a BBC file to a PC and then back to the Beeb, its
  attributes get lost and you cannot run the program. XFer does
  transfer these attributes (and stores them in additional files,
  according to a standardized format).
- It's got a terminal emulator that allows you operate your Beeb from
  your PC.
- It's fast (it approaches the theoretically obtainable speed of the Beeb's
  hardware) and reliable (due to CRC-checking and error reporting).
- It's very easy to use: all operations are carried out on the PC and
  results are shown at the PC side (including most BBC errors, like Disk
  full).

(Btw. if you wanna buy a second-hand car from me, let me know.)


The rough stuff
===============

You are allowed to use and freely distribute these programs as long as:
- you do not remove the authors' names;
- if you modify them, you clearly mark them as modified, both in the source
  code, README files, and in the program runtime banners;
- you distribute all files (including text files) together;
- you charge no money for them.

The author has done his best to make the programs work correctly and he
has witnessed several cases in which the programs worked as they should.
He can, however, not guarantee the programs always work correctly. It is
therefore your own responsibility to see to that you do not loose your
love letters, Killer Gorilla, your girlfriend, your mental health, or
anything else as a result of the use of this program.


System requirements
===================

You need:
- A reasonably fast (386 or above) PC with Windows95/98/NT/2000 or Linux
  and at least 4 Megabytes of memory.
- A BBC Model B with 32K of RAM and Basic II or above (or a BBC Master),
  a disk drive, and an Acorn DFS or a compatible DFS. (Some provisions
  have been made for the program also to be compatible with other DFSs.)


Files
=====

The following files are included in this package:

XFer.exe     -  The Win32 PC executable for XFer
xfer         -  The Linux/x86 executable for XFer
xfer.bas     -  The Beeb part of XFer
XFer.ini     -  File with initialization options for Win32 XFer
dotxfer     -   File with initialization options for Linux XFer

README       -  This file
XFerInC.txt  -  Instructions on how to operate XFer
SerCable.txt -  Instructions on how to make a serial cable for BBC <-> PC
                file transfer
Format.txt   -  Explanation of the standard format for storing BBC files
                on other computers
Changes.txt  -  Version history of XFer

Makefile     -  Makefile for nmake (Win32) or make (Linux)
first.c      -  First download
linux.c      -  Linux serial and keyboard interfaces
main.c       -  Main program, argument parsing, and utility routines
win32.c      -  Win32 serial and keyboard interfaces
xfer.c       -  Transfer routines.
xfer.h       -  Header file with definitions of interfaces


The text files give both required information and technical background
information. This technical information is preceded by # characters in
the left margin and can be skipped by anyone who's not interested. The
file Format.txt contains entirely technical background information.


Quick start
===========

If you want to use the program and not RTFM, proceed as below. If the
procedure doesn't work for you, I'm afraid you'll have to read the
f'ing manual (XFerInC.txt).

1. Make sure you have a serial cable connected to your Beeb and your PC. 
   (See the file SerCable.txt for instructions on how to make such a cable.)
   If you have a BBC Master, type *CONFIGURE DATA 5.

2. Edit the file XFer.ini
   - Set the baud rate setting to 9600. (If you get many file transmission
     errors later, lower it to 4800 or 2400. You can also try 19200 for extra
     speed.)
   - Set the COM port of the PC to the one you're using for file transfer.
   - Leave the time-out delay at its current setting. (If you get many 
     "connection timed out" errors later, increase the setting.)
   - If you have an Acorn-compatible DFS or a DFS that uses only
     single-letter directory names, leave the option "directories" on. If
     you have a DFS that allows for longer directory names (like ADFS), set
     the option to off.
   - If you have an Acorn-compatible DFS or a DFS that produces *INFO
     output that is similar to that of an Acorn DFS, leave the option
     "wildcards" on. Otherwise (e.g. if you use ADFS) set the option to
     off.

3. Transfer XFer.bas to the BBC.
   - Run "xfer -1"
   - Follow the instructions given on screen
   - XFer will then send over the file xfer.bas to your BBC
   - SAVE the file at your BBC when file transmission is finished

4. Execute XFer
   - RUN or CHAIN the program at your BBC (xfer can automatically do this if
     the -r option is specified)
   - Execute XFer on your PC

And off you go!


Thanx
=====

I would like to thank everybody on the BBC mailing list for helping me
with finding out how to make a good serial cable and with various
programming problems I had. I promised to give Gummy (gummy@treknet.is)
and Pete (pnt103@ugrad.cs.york.ac.uk) special mentions, so here they
are. Also thanks to Christian Philipps for writing and donating to the
public domain the Turbo Pascal unit V24, with low-level serial
communications routines; V24 was used in the writing of XFer. Many
thanks to all of the beta-testers, and in particular to Steve
(steve@klaatu.demon.co.uk). Thanx to Robert Schmidt (rsv@vingmed.no)
for making XFer available via his The BBC Lives! WWW-pages. The format
used by XFer for storing BBC files on a PC was first described by
Wouter Scholten (wouters@cistron.nl).


Comments
========

If you have any questions, comments, or suggestions for improvement,
please mail me. Bug reports are especially welcome; I will try to fix
the reported bug.

BEFORE REPORTING A BUG, PLEASE CAREFULLY READ THE SECTIONS ABOUT XFER.INI
AND TROUBLESHOOTING IN THE FILE XFER.TXT

If you submit a bug report, please describe *exactly*:
- what the error is that occurred;
- what you did to make it occur;
- under what circumstances it occurred;
- what you PC configuration is (which OS, processor, speed, amount of memory);
- what your BBC configuration is (model B or Master, which Basic, which DFS,
  sideways ROMs, amount of memory). 


Februari 1997,
Mark de Weger

Updated November 1999, Angus Duggan (angus@harlequin.com)

$Id: README,v 1.2 1999/11/07 00:35:51 angus Exp $
