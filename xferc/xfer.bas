   10REM $Id: xfer.bas,v 1.8 1999/11/08 09:38:34 angus Exp $
   20REM ***************************************
   30REM * Xfer/BBC                            *
   40REM * BBC <-> PC Serial Transfer program  *
   50REM * BBC End (Slave)                     *
   60REM * (c) Mark de Weger, 1996-1997        *
   70REM * (c) Angus Duggan, 1999              *
   80REM ***************************************
   90:
  100:
  110REM *****************
  120REM Main program
  130REM *****************
  140:
  150REM Initialisation
  160PROCreset
  170REM Clear serial port buffers
  180*FX 21,1
  190*FX 21,2
  200MODE 7
  210ON ERROR PROCfatal_error
  220PROCsetvars
  230PROCassemble
  240PROCinitconnection
  250PROCmain
  260END
  270:
  280REM Main procedure
  290DEF PROCmain
  300REM Switch RS423 Escape off
  310*FX 181,1
  320REM Switch RS423 Printer selection off
  330*FX 5,0
  340REM Switch RS423 Output off
  350*FX 3,0
  360REM Switch output to printer off
  370VDU 3
  380REPEAT
  390REM Switch RS423 Output off
  400*FX 3,0
  410PROCstatus("waiting for command","",0)
  420g$=GET$
  430IF (g$="*") OR (g$="S") OR (g$="R") OR (g$="I") OR (g$="X") THEN name$=FNread_string
  440IF g$="*" THEN PROCoscli(name$)
  450IF g$="S" THEN PROCsendfile(name$)
  460IF g$="X" THEN PROCsendcrc(name$)
  470IF g$="I" THEN PROCsendinf(name$)
  480IF g$="R" THEN PROCreceivefile(name$)
  490IF g$="T" THEN PROCtermemu
  500REM C: command to send current directory name (before transfer of file)
  510IF g$="C" THEN PROCsenddir
  520REM B: command to send current boot option
  530IF g$="B" THEN PROCsendboot
  540REM D: command to receive and set boot option
  550IF g$="F" THEN PROCreceiveboot
  560REM N: command to send disc size
  570IF g$="N" THEN PROCsendsize
  580REM G: command to send disc sectors
  590IF g$="G" THEN PROCsendtrack
  600UNTIL g$="Q" OR g$="E"
  610:
  620REM Quit
  630PROCreset
  640REM Clear RS423 input buffer
  650*FX 21,1
  660IF g$="Q" THEN PROCstatus("quitting XFER","",0) ELSE PROCstatus("error at PC; quitting XFER","",0)
  670END
  680:
  690:
  700REM ******************
  710REM Oscli command
  720REM ******************
  730:
  740REM Carry out * command
  750DEF PROCoscli(oscli$)
  760REM Switch output to printer on (*FX 3,3 doesn't work for *-commands)
  770VDU 2
  780REM Select RS423 for printer output
  790*FX 5,2
  800ON ERROR PROCallowed_error(err_txt$)
  810OSCLI(oscli$)
  820ON ERROR PROCfatal_error
  830PRINT sync_text$
  840REM Switch output to printer off
  850VDU 3
  860REM Deselect RS423 for printer output
  870*FX 5,0
  880ENDPROC
  890:
  900:
  910REM ******************
  920REM Send files to PC
  930REM ******************
  940:
  950REM Send file
  960DEF PROCsendfile(f$)
  970ON ERROR PROCallowed_error(err_txt$):ENDPROC
  980fh%=OPENIN(f$)
  990REM Print string to show OPENIN went well
 1000*FX 3,3
 1010PRINT sync_text$
 1020ON ERROR PROCallowed_error(""):ENDPROC
 1030REM If file does not exist: send 0 to pc
 1040PROCwrite_integer(fh%)
 1050*FX 3,0
 1060ON ERROR PROCfatal_error
 1070IF fh%=0 THEN ENDPROC
 1080ON ERROR PROCallowed_error(""):ENDPROC
 1090fs%=EXT#fh%
 1100PROCstatus("sending file",f$,fs%)
 1110REM Select serial port for output
 1120*FX 3,3
 1130REM Send file size
 1140PROCwrite_integer(fs%)
 1150REM Send file contents
 1160crc2%=FNsfc(fh%,fs%)
 1170CLOSE#fh%
 1180REM Send CRC
 1190PROCwrite_integer(crc2%)
 1200ON ERROR PROCfatal_error
 1210REM Select VDU for output
 1220*FX 3,0
 1230ENDPROC
 1240:
 1250REM Send file contents
 1260DEF FNsfc(fh%,fs%)
 1270REM Initialise
 1280!crc%=0
 1290?pblock%=fh%
 1300!filelength%=fs%
 1310REM Do it
 1320CALL sendfile
 1330=!crc%
 1340:
 1350REM Send CRC
 1360DEF PROCsendcrc(f$)
 1370ON ERROR PROCallowed_error(err_txt$):ENDPROC
 1380fh%=OPENIN(f$)
 1390REM Print string to show OPENIN went well
 1400*FX 3,3
 1410PRINT sync_text$
 1420ON ERROR PROCallowed_error(""):ENDPROC
 1430REM If file does not exist: send 0 to pc
 1440PROCwrite_integer(fh%)
 1450*FX 3,0
 1460ON ERROR PROCfatal_error
 1470IF fh%=0 THEN ENDPROC
 1480ON ERROR PROCallowed_error(""):ENDPROC
 1490fs%=EXT#fh%
 1500PROCstatus("calculating CRC",f$,0)
 1510REM disable VDU and printer driver
 1520*FX 3,6
 1530REM Send file contents to null
 1540crc2%=FNsfc(fh%,fs%)
 1550CLOSE#fh%
 1560REM Select serial port for output
 1570*FX 3,3
 1580REM Send CRC
 1590PROCwrite_integer(crc2%)
 1600ON ERROR PROCfatal_error
 1610REM Select VDU for output
 1620*FX 3,0
 1630ENDPROC
 1640:
 1650REM Send .inf file
 1660DEF PROCsendinf(f$)
 1670REM Osfile 5: reads file's catalog info
 1680$nblock%=f$
 1690?pblock%=nblock% MOD 256
 1700pblock%?1=nblock% DIV 256
 1710X%=pblock% MOD 256
 1720Y%=pblock% DIV 256
 1730A%=5
 1740ON ERROR PROCallowed_error(err_txt$):ENDPROC
 1750type%=USR osfile% AND 255
 1760ON ERROR PROCfatal_error
 1770load%=pblock%!2
 1780exec%=pblock%!6
 1790length%=pblock%!&0A
 1800attr%=pblock%!&0E
 1810*FX 3,3
 1820PRINT f$;" ";~load%;" ";~exec%;" ";~length%;" ";~attr%;" ";type%
 1830*FX 3,0
 1840ENDPROC
 1850:
 1860:
 1870REM **********************
 1880REM Receive files from PC
 1890REM **********************
 1900:
 1910REM Receive file
 1920DEF PROCreceivefile(f$)
 1930REM Receive file attributes+length
 1940start%=FNread_integer
 1950exec%=FNread_integer
 1960length%=FNread_integer
 1970attr%=FNread_integer
 1980PROCstatus("receiving file",f$,length%)
 1990ON ERROR PROCallowed_error(err_txt$):ENDPROC
 2000fh%=OPENOUT(f$)
 2010REM Print string to show OPENOUT went well
 2020*FX 3,3
 2030PRINT sync_text$
 2040*FX 3,0
 2050REM Receive file contents
 2060crc2%=FNrfc(fh%,length%)
 2070CLOSE#fh%
 2080REM IF crc2%=-1 THEN ENDPROC
 2090crcrec%=FNread_integer
 2100REM Tell pc if crc error
 2110*FX 3,3
 2120IF crcrec%<>crc2% THEN PRINT err_txt2$:ENDPROC ELSE PRINT sync_text$
 2130*FX 3,0
 2140REM Osfile 1: set file attributes
 2150$nblock%=f$
 2160?pblock%=nblock% MOD 256
 2170pblock%?1=nblock% DIV 256
 2180pblock%!2=start%
 2190pblock%!6=exec%
 2200pblock%!&0A=length%
 2210pblock%!&0E=attr%
 2220X%=pblock% MOD 256
 2230Y%=pblock% DIV 256
 2240A%=1
 2250CALL osfile%
 2260ON ERROR PROCfatal_error
 2270REM Print string to show receive went well
 2280*FX 3,3
 2290PRINT sync_text$
 2300*FX 3,0
 2310ENDPROC
 2320:
 2330REM Receive file contents
 2340DEF FNrfc(fh%,fs%)
 2350REM Initialise
 2360!crc%=0
 2370!filelength%=fs%
 2380?pblock%=fh%
 2390REM Do it
 2400CALL receivefile
 2410=!crc%
 2420:
 2430:
 2440REM ****************************
 2450REM Terminal emulation
 2460REM ****************************
 2470:
 2480REM Start terminal emulation
 2490DEF PROCtermemu
 2500PROCstatus("terminal emulation","",0)
 2510REM Select RS423 as printer (*FX 3,3 doesn't work for *-commands)
 2520*FX 5,2
 2530REM Switch output to printer on
 2540VDU 2
 2550REM Enable RS423 Escape
 2560*FX 181,0
 2570END
 2580ENDPROC
 2590:
 2600:
 2610REM ****************************
 2620REM Send current directory name
 2630REM ****************************
 2640:
 2650DEF PROCsenddir
 2660dir$=FNgetcurrentdir
 2670REM Switch RS423 output on
 2680*FX3,3
 2690PRINT dir$
 2700REM Switch RS423 output off
 2710*FX3,0
 2720ENDPROC
 2730:
 2740REM ****************************
 2750REM Send size of disc
 2760REM ****************************
 2770:
 2780REM Send disc size
 2790DEF PROCsendsize
 2800ON ERROR PROCallowed_error(err_txt$):ENDPROC
 2810X%=pblock% MOD 256
 2820Y%=pblock% DIV 256
 2830A%=&7E
 2840CALL osword%
 2850ON ERROR PROCfatal_error
 2860REM Switch on RS423 output
 2870*FX3,3
 2880PROCwrite_integer(!pblock%)
 2890REM Switch RS423 output off
 2900*FX3,0
 2910ENDPROC
 2920:
 2930:
 2940REM ****************************
 2950REM 8271 read track
 2960REM ****************************
 2970:
 2980REM Send read track and perform CRC
 2990DEF PROCsendtrack
 3000?pblock%=FNread_integer
 3010pblock%!1=buffer%
 3020pblock%?7=FNread_integer
 3030!crc%=0
 3040PROCstatus("sending drive "+STR$(?pblock%)+" track "+STR$(pblock%?7),"",0)
 3050REM Switch on RS423 output
 3060*FX3,3
 3070ON ERROR PROCallowed_error("")
 3080CALL readtrack%
 3090IF ?pblock%<>0 THEN PRINT err_txt2$ ELSE PROCwrite_integer(!crc%)
 3100ON ERROR PROCfatal_error
 3110REM Switch off RS423 output
 3120*FX3,0
 3130ENDPROC
 3140:
 3150:
 3160REM ****************************
 3170REM Send set/get boot option
 3180REM ****************************
 3190:
 3200REM Send !BOOT option
 3210DEF PROCsendboot
 3220REM Osgbpb 5: read boot option
 3230ON ERROR PROCallowed_error(err_txt$)
 3240pblock%!1=nblock%
 3250X%=pblock% MOD 256
 3260Y%=pblock% DIV 256
 3270A%=5
 3280CALL osgbpb%
 3290ON ERROR PROCfatal_error
 3300*FX 3,3
 3310PROCwrite_integer(?(nblock%+?nblock%+1))
 3320*FX 3,0
 3330ENDPROC
 3340:
 3350REM Receive and set !BOOT option
 3360DEF PROCreceiveboot
 3370REM Osbyte 139: *OPT X%,Y%
 3380Y%=FNread_integer
 3390X%=4
 3400A%=139
 3410ON ERROR PROCallowed_error(err_txt$)
 3420CALL osbyte%
 3430ON ERROR PROCfatal_error
 3440*FX 3,3
 3450PRINT sync_text$
 3460*FX 3,0
 3470ENDPROC
 3480:
 3490:
 3500REM ****************************
 3510REM Initialisation/error/status
 3520REM ****************************
 3530:
 3540REM Initialise and check connection
 3550DEF PROCinitconnection
 3560PROCstatus("Waiting for connection","",0)
 3570REM 1200 Baud RS423 Receiving
 3580*FX 7,4
 3590REM Receive from RS423
 3600*FX 2,1
 3610REM Test connection
 3620text$=FNread_string
 3630IF text$<>sync_text$ THEN PROCreset:PRINT "Invalid data received. Please try again.":END
 3640REM Get protocol version
 3650p%=FNread_integer
 3660IF p%<>protocol% THEN PROCreset:PRINT "Incompatible XFer protocol version"'"Received ";p%;" required ";protocol%:END
 3670REM Get baud rate and set it
 3680x%=FNread_integer
 3690PRINT
 3700PRINT "Initializing at ";STR$(x%);" baud."
 3710PRINT
 3720REM Osbyte 7: set RS423 receiving speed
 3730IF x%=1200 THEN X%=4
 3740IF x%=2400 THEN X%=5
 3750IF x%=4800 THEN X%=6
 3760IF x%=9600 THEN X%=7
 3770IF x%=19200 THEN X%=8
 3780A%=7
 3790CALL osbyte%
 3800REM Osbyte 8: set RS423 sending speed
 3810A%=8
 3820CALL osbyte%
 3830ENDPROC
 3840:
 3850REM Initialise variables
 3860DEF PROCsetvars
 3870DIM pblock% &11
 3880DIM nblock% 256
 3890osbyte%=&FFF4
 3900osword%=&FFF1
 3910oscli%=&FFF7
 3920osfile%=&FFDD
 3930osgbpb%=&FFD1
 3940oswrch%=&FFEE
 3950sync_text$="-----BBC-----PC-----"
 3960err_txt$="-----BBCerror1-----PC-----"
 3970err_txt2$="-----BBCerror2-----PC-----"
 3980@%=&90A
 3990REM Variables for mc
 4000bufsize%=4096
 4010crc%=&70
 4020filelength%=&74
 4030bufptr%=&78
 4040buflen%=&7A
 4050protocol%=100001
 4060ENDPROC
 4070:
 4080REM Print status of connection
 4090DEF PROCstatus(status$,file$,length%)
 4100CLS
 4110PRINT CHR$141;"XFER/BBC"
 4120PRINT CHR$141;"XFER/BBC"
 4130PRINT
 4140PRINT "(c) 1996 Mark de Weger"
 4150PRINT "    1999 Angus Duggan"
 4160PRINT
 4170PRINT ""
 4180PRINT "Status: ";status$
 4190IF file$<>"" THEN PRINT "  File name: ";file$
 4200IF length%<>0 THEN PRINT "  File length: ";STR$(length%)
 4210PRINT ""
 4220ENDPROC
 4230:
 4240REM Reset RS423
 4250DEF PROCreset
 4260ON ERROR OFF
 4270REM Close serial port and reselect keyboard input
 4280*FX 2,0
 4290REM Flush serial port input buffer
 4300*FX 21,1
 4310REM Reselect VDU output
 4320*FX 3,0
 4330REM Deselect RS423 as printer destination
 4340*FX 5,0
 4350REM Switch printer output off
 4360VDU 3
 4370REM Close remaining open files
 4380CLOSE#0
 4390PRINT ""
 4400ENDPROC
 4410:
 4420REM Fatal error
 4430DEF PROCfatal_error
 4440PROCreset
 4450REPORT
 4460PRINT " at line ";ERL
 4470END
 4480ENDPROC
 4490:
 4500:
 4510REM ********************
 4520REM RS423 Utilities
 4530REM ********************
 4540:
 4550REM Read string
 4560DEF FNread_string
 4570LOCAL string$,g$
 4580string$=""
 4590REPEAT
 4600g$=GET$
 4610REM IF ASC(g$)<32 THEN PRINT "~ ";~ASC(g$);" "; ELSE PRINT g$;" ";~ASC(g$);" ";
 4620IF g$<>CHR$(13) THEN string$=string$+g$
 4630UNTIL g$=CHR$(13)
 4640PRINT 'string$
 4650=string$
 4660:
 4670REM Read integer
 4680DEF FNread_integer
 4690LOCAL s$
 4700s$=FNread_string
 4710=VAL(s$)
 4720:
 4730REM Write integer
 4740DEF PROCwrite_integer(i%)
 4750LOCAL s$
 4760s$=STR$(i%)
 4770PRINT s$
 4780ENDPROC
 4790:
 4800:
 4810REM ********************
 4820REM Other utilities
 4830REM ********************
 4840:
 4850REM Get current directory name
 4860DEF FNgetcurrentdir
 4870LOCAL s$,dir%,index%
 4880REM Osgbpb 6: read directory (and device)
 4890pblock%!1=nblock%
 4900X%=pblock% MOD 256
 4910Y%=pblock% DIV 256
 4920A%=6
 4930CALL osgbpb%
 4940dir%=nblock%+?nblock%+1
 4950IF ?dir%=0 THEN =""
 4960FOR index%=1 TO ?dir%
 4970s$=s$+CHR$(dir%?index%)
 4980NEXT
 4990=s$
 5000:
 5010REM Error to be trapped
 5020DEF PROCallowed_error(pc$)
 5030ON ERROR PROCfatal_error
 5040REM Close open files
 5050CLOSE#0
 5060REM Switch off RS423 output
 5070*FX 3,0
 5080REM De-select RS423 printer
 5090*FX 5,0
 5100REM Switch output to printer off
 5110VDU 3
 5120REM Switch RS423 Escape off
 5130*FX 181,1
 5140PROCstatus("error, waiting for PC to respond","",0)
 5150REM Switch on RS423 output
 5160*FX 3,3
 5170REM Print string to tell PC of error
 5180IF pc$<>"" THEN PRINT pc$
 5190REM Wait for pc to respond acknowledgement of error
 5200pc$=""
 5210REPEAT
 5220g$=GET$
 5230IF g$<>"" THEN pc$=pc$+g$ ELSE pc$=""
 5240IF LEN(pc$)>LEN(err_txt$) THEN pc$=RIGHT$(pc$,LEN(pc$)-1)
 5250UNTIL pc$=err_txt$
 5260REM Send error to PC
 5270REPORT
 5280PRINT
 5290REM Switch off RS423 output
 5300*FX 3,0
 5310PROCmain
 5320:
 5330:
 5340REM ***********************
 5350REM Machine code generation
 5360REM ***********************
 5370:
 5380DEF PROCassemble
 5390DIM mc% 600
 5400DIM buffer% bufsize%
 5410FOR opt%=0 TO 2 STEP 2
 5420P%=mc%
 5430[
 5440OPT opt%
 5450\
 5460\ Receive file
 5470.receivefile
 5480\ WHILE !filelength%<>0
 5485CLC
 5490LDA filelength%+3
 5500BMI recvexit
 5510ORA filelength%+2
 5520ORA filelength%+1
 5530ORA filelength%
 5540BEQ recvexit
 5550\ set up OSGBPB pointers
 5560JSR setsize
 5570\ receive block of data from RS423
 5580\ *bufptr%=buffer%
 5590LDA #buffer% MOD 256
 5600STA bufptr%
 5610LDA #buffer% DIV 256
 5620STA bufptr%+1
 5630\ *buflen%=-pblock%!5
 5640SEC
 5650LDA #0
 5660SBC pblock%+5
 5670STA buflen%
 5680LDA #0
 5690SBC pblock%+6
 5700STA buflen%+1
 5710\
 5720.recvblock
 5730\ Y%=get from RS423 input buffer
 5740LDA #145
 5750LDX #1
 5760JSR osbyte%
 5770\ keep trying until got a byte (should put a timeout here)
 5780BCS recvblock
 5790TYA
 5800LDX #0
 5810STA (bufptr%,X)
 5820JSR crccalc
 5830INC bufptr%
 5840BNE recvnext
 5850INC bufptr%+1
 5860.recvnext
 5870INC buflen%
 5880BNE recvblock
 5890INC buflen%+1
 5900BNE recvblock
 5910\ save received block to file
 5920LDA #2
 5930LDX #pblock% MOD 256
 5940LDY #pblock% DIV 256
 5950JSR osgbpb%
 5960BCC receivefile
 5970.recvexit
 5980RTS
 5990\
 6000\ Send file
 6010.sendfile
 6020\ WHILE !filelength%<>0
 6025CLC
 6030LDA filelength%+3
 6040BMI sendexit
 6050ORA filelength%+2
 6060ORA filelength%+1
 6070ORA filelength%
 6080BEQ sendexit
 6090\ set up OSGBPB pointers
 6100JSR setsize
 6110\ load block from disc using OSGBPB
 6120LDA #4
 6130LDX #pblock% MOD 256
 6140LDY #pblock% DIV 256
 6150JSR osgbpb%
 6160\ if read is too short, quit
 6170BCS sendexit
 6180\ send block to pc and calculate crc
 6190\ *bufptr%=buffer%
 6200LDA #buffer% MOD 256
 6210STA bufptr%
 6220LDA #buffer% DIV 256
 6230STA bufptr%+1
 6240\ *buflen%=pblock%!1-buffer%
 6250SEC
 6260LDA pblock%+1
 6270SBC #buffer% MOD 256
 6280STA buflen%
 6290LDA pblock%+2
 6300SBC #buffer% DIV 256
 6310STA buflen%+1
 6320LDY #0
 6330.sbloop
 6340\ VDU ?(bufptr%)
 6350LDA (bufptr%),Y
 6360JSR oswrch%
 6370JSR crccalc
 6380INY
 6390BNE sbnext
 6400INC bufptr%+1
 6410DEC buflen%+1
 6420BNE sbloop
 6430.sbnext
 6440CPY buflen%
 6450BNE sbloop
 6460LDA buflen%+1
 6470BNE sbloop
 6480JMP sendfile
 6490.sendexit
 6500RTS
 6510\
 6520\ Merge accumulator into CRC. Invalidates A,X,P
 6530.crccalc
 6540EOR crc%+3
 6550STA crc%+3
 6560LDX #8
 6570.crcloop
 6580LDA crc%+3
 6590ROL A
 6600BCC crcclear
 6610LDA crc%
 6620EOR #&57
 6630STA crc%
 6640.crcclear
 6650ROL crc%
 6660ROL crc%+1
 6670ROL crc%+2
 6680ROL crc%+3
 6690DEX
 6700BNE crcloop
 6710RTS
 6720\
 6730\ 8271 command read track of data info buffer, and calculate CRC
 6740.readtrack%
 6750LDA #1
 6760STA pblock%+5
 6770LDA #&29
 6780STA pblock%+6
 6790LDX #pblock% MOD 256
 6800LDY #pblock% DIV 256
 6810LDA #&7F
 6820JSR osword%
 6830LDA pblock%+8
 6840BNE trackdone
 6850LDA #3
 6860STA pblock%+5
 6870LDA #&13:\ read multiple sectors
 6880STA pblock%+6
 6890LDA #0
 6900STA pblock%+8
 6910LDA #&29
 6920STA pblock%+9
 6930LDA #&7F
 6940JSR osword%
 6950LDA pblock%+10
 6960BNE trackdone
 6970LDA #buffer% MOD 256
 6980STA bufptr%
 6990LDA #buffer% DIV 256
 7000STA bufptr%+1
 7010LDY #0
 7020LDA #10
 7030STA buflen%
 7040.trackcrc
 7050LDA (bufptr%),Y
 7060JSR oswrch%
 7070JSR crccalc
 7080INY
 7090BNE trackcrc
 7100INC bufptr%+1
 7110DEC buflen%
 7120BNE trackcrc
 7130LDA pblock%+10
 7140.trackdone
 7150STA pblock%
 7160RTS
 7170\
 7180\ set buffer and size pointers for OSGBPB in pblock
 7190.setsize
 7200\ pblock%!1=buffer%
 7210LDA #buffer% MOD 256
 7220STA pblock%+1
 7230LDA #buffer% DIV 256
 7240STA pblock%+2
 7250LDA #0
 7260STA pblock%+3
 7270STA pblock%+4
 7280\ pblock%!5=filelength%:\ filelength%=filelength%-bufsize%
 7290SEC
 7300LDA filelength%
 7310STA pblock%+5
 7320SBC #bufsize% MOD 256
 7330STA filelength%
 7340LDA filelength%+1
 7350STA pblock%+6
 7360SBC #bufsize% DIV 256
 7370STA filelength%+1
 7380LDA filelength%+2
 7390STA pblock%+7
 7400SBC #0
 7410STA filelength%+2
 7420LDA filelength%+3
 7430STA pblock%+8
 7440SBC #0
 7450STA filelength%+3
 7460BCC donesize
 7470\ IF pblock%!5 >= bufsize% THEN pblock%!5=bufsize%
 7480LDA #bufsize% MOD 256
 7490STA pblock%+5
 7500LDA #bufsize% DIV 256
 7510STA pblock%+6
 7520LDA #0
 7530STA pblock%+7
 7540STA pblock%+8
 7550.donesize
 7560RTS
 7570]
 7580NEXT
 7590ENDPROC
