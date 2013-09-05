# $Id: Makefile,v 1.6 1999/11/07 00:49:38 angus Exp $
#
# Makefile for XFerC, a re-implementation in C of Mark de Weger's XFer program
# for transferring files between the BBC and a PC. This program is written to
# run on Win32 (Win95, 98, NT, and 2000) and Linux. This makefile can be used
# to compile with nmake and MSVC on Win32 or gcc on Linux.

# For WIN32:
WIN32_CC=cl
WIN32_CFLAGS=-DWIN32 -DWIN32_LEAN_AND_MEAN -W3 # -Zi
WIN32_EXE=.exe
WIN32_OBJ=obj
WIN32_LINK=link -out:xfer.exe # -debug:full

# For Linux:
LINUX_CC=gcc
LINUX_CFLAGS=-DLINUX -Wall -ansi -O # -g
LINUX_EXE=
LINUX_OBJ=o
LINUX_LINK=gcc -o xfer

all:
	@echo Must specify target win32 or linux.

win32:
	$(MAKE) $(MAKEFLAGS) CC="$(WIN32_CC)" CFLAGS="$(WIN32_CFLAGS)" \
		EXE="$(WIN32_EXE)" LL="$(WIN32_LINK)" OBJ="$(WIN32_OBJ)" \
		xfer.exe

linux:
	$(MAKE) $(MAKEFLAGS) CC="$(LINUX_CC)" CFLAGS="$(LINUX_CFLAGS)" \
		EXE="$(LINUX_EXE)" LL="$(LINUX_LINK)" OBJ="$(LINUX_OBJ)" \
		xfer

xfer$(EXE): xfer.$(OBJ) linux.$(OBJ) win32.$(OBJ) first.$(OBJ) main.$(OBJ)
	$(LL) xfer.$(OBJ) linux.$(OBJ) win32.$(OBJ) first.$(OBJ) main.$(OBJ)

linux.c win32.c main.c first.c xfer.c: xfer.h

realclean: clean
	rm -f xfer.exe xfer

clean:
	rm -f *.o *.obj

TAGS: linux.c win32.c xfer.c first.c main.c xfer.h
	etags -o TAGS linux.c win32.c xfer.c first.c main.c xfer.h

# $Log: Makefile,v $
# Revision 1.6  1999/11/07 00:49:38  angus
# Remove debug flags in preparation for release
#
# Revision 1.5  1999/11/06 23:09:50  angus
# Avoid LINK variable because of nmake default rules
#
# Revision 1.4  1999/11/05 02:43:05  angus
# Linux changes; timeouts for serial read, keyboard open/close, directory
# searching for send file.
#
# Revision 1.3  1999/11/02 08:36:46  angus
# Many updates; Win32 keyboard/console/serial interface, serial transfer, info
# file read and save.
#
# Revision 1.2  1999/10/27 07:01:11  angus
# Add main.c and first.c, split first-time transfer, parameter
# encapsulation, initial configuration, argument parsing
#
# Revision 1.1.1.1  1999/10/25 16:51:23  angus
# Development CVS import
#
