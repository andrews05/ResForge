# Template Editor

The following is a list of template element types that have been defined by various editors. ResKnife currently supports:
* All of [ResEdit's original types](https://developer.apple.com/library/archive/documentation/mac/pdf/ResEditReference.pdf) (34)
* Many of [Resorcerer's extensions](http://www.digitale-heimat.de/~anne/anne/Sommer_2000/pdf/resorcerer%20docu/383%20The%20Template%20Editor.pdf) (51 of 92)
* All of [Rezilla's extensions](https://bdesgraupes.pagesperso-orange.fr/DocHTML/EN/RezillaHelp/47.html) (5)
* ResKnife's own extensions (10)

### Key

🟢 Full Support

🔵 Read-Only

🟡 Faked (interpreted as a different type)

🔴 Not Yet Supported

### Decimal and Hex Integer Field Types

Type|Description|Size|ResEdit|Resorcerer|Rezilla|ResKnife
----|-----------|----|-------|----------|-------|--------
DBYT|Signed Decimal Byte|1 byte|✓|✓|✓|🟢
DWRD|Signed Decimal Word|2 bytes|✓|✓|✓|🟢
DLNG|Signed Decimal Long|4 bytes|✓|✓|✓|🟢
DLLG|Signed Decimal Long Long|8 bytes||||🟢
UBYT|Unsigned Decimal Byte|1 byte||✓|✓|🟢
UWRD|Unsigned Decimal Word|2 bytes||✓|✓|🟢
ULNG|Unsigned Decimal Long|4 bytes||✓|✓|🟢
ULLG|Unsigned Decimal Long Long|8 bytes||||🟢
HBYT|Hex Byte|1 byte|✓|✓|✓|🟢
HWRD|Hex Word|2 bytes|✓|✓|✓|🟢
HLNG|Hex Long|4 bytes|✓|✓|✓|🟢
HLLG|Hex Long Long|8 bytes||||🟢

### Bit and Bit Field Types

Type|Description|Size|ResEdit|Resorcerer|Rezilla|ResKnife
----|-----------|----|-------|----------|-------|--------
BBIT|Bit Within a Byte|1 bit|✓|✓|✓|🟢
BBnn|Bit Field Within a Byte|_nn_ bits||✓|✓|🟢
WBIT|Bit Within a Word|1 bit||✓|✓|🟢
WBnn|Bit Field Within a Word|_nn_ bits||✓|✓|🟢
LBIT|Bit Within a Long|1 bit||✓|✓|🟢
LBnn|Bit Field Within a Long|_nn_ bits||✓|✓|🟢
BOOL|Boolean Word|2 bytes|✓|✓|✓|🟢
BFLAG|Byte Boolean Flag (low-order bit)|1 byte||✓|✓|🟢
WFLAG|Word Boolean Flag (low-order bit)|2 bytes||✓|✓|🟢
LFLAG|Long Boolean Flag (low-order bit)|4 bytes||✓|✓|🟢
BORV|OR Byte Value|1 byte|||✓|🟢
WORV|OR Word Value|2 bytes|||✓|🟢
LORV|OR Long Value|4 bytes|||✓|🟢

### Floating and Fixed Point Field Types

Type|Description|Size|ResEdit|Resorcerer|Rezilla|ResKnife
----|-----------|----|-------|----------|-------|--------
REAL|Single Precision Float|4 bytes||✓||🟢
DOUB|Double Precision Float|8 bytes||✓||🟢
EXTN|Extended 80-bit SANE Float|10 bytes||✓||🔴
XT96|Extended 96-bit SANE Float|12 bytes||✓||🔴
UNIV|THINK C Universal 96-bit Float|12 bytes||✓||🔴
FIXD|16:16 Fixed Point Number|4 bytes||✓||🟡
FRAC|2:30 Fixed Point Number|4 bytes||✓||🟡
SFRC|0:16 Fixed Point Small Fraction|2 bytes||✓||🟡
FWID|4:12 Fixed Point Font Width|2 bytes||✓||🟡
FXYZ|1:15 Fixed Point Colour Component|2 bytes||✓||🟡


### ASCII Text String Field Types

Type|Description|Size|ResEdit|Resorcerer|Rezilla|ResKnife
----|-----------|----|-------|----------|-------|--------
PSTR|Pascal String|1 to 256|✓|✓|✓|🟢
ESTR|Pascal String|2 to 256|✓|✓|✓|🟢
PPST|Even Pascal String (pad included)|2 to 256||✓|✓|🔴
OSTR|Pascal String Odd-Padded|1 to 255|✓|✓|✓|🟢
CSTR|Null-Terminated C String|1 or more|✓|✓|✓|🟢
ECST|Even-Padded C String|2 or more|✓|✓|✓|🟢
OCST|C String Odd-Padded|1 or more|✓|✓|✓|🟢
BSTR|Byte Length String (same as PSTR)|1 to 256||✓|✓|🟢
WSTR|Word Length String|2 to 64KB|✓|✓|✓|🟢
LSTR|Long Length String|4 to 4MB|✓|✓|✓|🟢
TXTS|Sized Text Dump|any||✓||🔴
Pnmm|Pascal String with Fixed Padding|$_nmm_ bytes|✓|✓|✓|🟢
Cnmm|C String with Fixed Padding|$_nmm_ bytes|✓|✓|✓|🟢
Tnmm|Text with Fixed Padding|$_nmm_ bytes||✓|✓|🔴

### Hexadecimal Dump Field Types

Type|Description|Size|ResEdit|Resorcerer|Rezilla|ResKnife
----|-----------|----|-------|----------|-------|--------
BHEX|Byte Length Hex Dump|1 to 256||✓|✓|🔵
WHEX|Word Length Hex Dump|2 to 64KB||✓|✓|🔵
LHEX|Long Length Hex Dump|4 to 4MB||✓|✓|🔵
BSHX|Byte Length - 1 Hex Dump|1 to 255||✓|✓|🔵
WSHX|Word Length - 2 Hex Dump|2 to 64KB-2||✓|✓|🔵
LHEX|Long Length - 4 Hex Dump|4 to 4MB-4||✓|✓|🔵
Hnmm|Fixed-Length Hex Dump|$_nmm_ bytes|✓|✓|✓|🔵
HEXS|Sized Hex Dump|any||✓||🔴
HEXD|Hex Dump|any|✓|✓|✓|🔵

### Skip Offset Field Types

Type|Description|Size|ResEdit|Resorcerer|Rezilla|ResKnife
----|-----------|----|-------|----------|-------|--------
BSKP|Offset to SKPE in Byte, inclusive|1 byte||✓|✓|🔴
WSKP|Offset to SKPE in Word, inclusive|2 bytes||✓|✓|🔴
LSKP|Offset to SKPE in Byte, inclusive|4 bytes||✓|✓|🔴
BSIZ|Offset to SKPE in Byte, exclusive|1 byte||✓|✓|🔴
WSIZ|Offset to SKPE in Word, exclusive|2 bytes||✓|✓|🔴
LSIZ|Offset to SKPE in Byte, exclusive|4 bytes||✓|✓|🔴
SKPE|End of Skip or Sizeof|0 bytes||✓|✓|🔴

### Counted Lists/Arrays

Type|Description|Size|ResEdit|Resorcerer|Rezilla|ResKnife
----|-----------|----|-------|----------|-------|--------
BCNT|Byte Count of List Items|1 byte||✓|✓|🟢
OCNT|One-Based Count of List Items|2 bytes|✓|✓|✓|🟢
WCNT|Word Count of List Items (same as OCNT)|2 bytes||✓|✓|🟢
LCNT|Long Count of List Items|4 bytes||✓|✓|🟢
ZCNT|Zero-Based Word Count of List Items|2 bytes|✓|✓|✓|🟢
LZCT|Zero-Based Long Count of List Items|4 bytes||✓|✓|🟢
FCNT|Fixed Count of List Items|0 bytes||✓|✓|🟢
LSTC|Begin Counted List Item|0 bytes|✓|✓|✓|🟢
LSTB|Begin Non-Counted List Item|0 bytes|✓|✓|✓|🟢
LSTS|Begin Sized List Item|0 bytes||✓||🔴
LSTZ|Begin List Item, Ending in Zero Byte|0 bytes|✓|✓|✓|🟢
LSTE|End of any List Item|0 or 1 bytes|✓|✓|✓|🟢
SELF|List Item is Entire TMPL|any||✓||🔴
Rnmm|Repeat Following Element $_nmm_ Times|0 bytes||||🟢

### Key Values for Subsequent Variant Items

Type|Description|Size|ResEdit|Resorcerer|Rezilla|ResKnife
----|-----------|----|-------|----------|-------|--------
KBYT|Signed Decimal Byte Key|1 byte||✓|✓|🟢
KWRD|Signed Decimal Word Key|2 bytes||✓|✓|🟢
KLNG|Signed Decimal Long Key|4 bytes||✓|✓|🟢
KLLG|Signed Decimal Long Long Key|8 bytes||||🟢
KUBT|Unsigned Decimal Byte Key|1 byte||✓|✓|🟢
KUWD|Unsigned Decimal Word Key|2 bytes||✓|✓|🟢
KULG|Unsigned Decimal Long Key|4 bytes||✓|✓|🟢
KULL|Unsigned Decimal Long Long Key|8 bytes||||🟢
KHBT|Unsigned Hex Byte Key|1 byte||✓|✓|🟢
KHWD|Unsigned Hex Word Key|2 bytes||✓|✓|🟢
KHLG|Unsigned Hex Long Key|4 bytes||✓|✓|🟢
KHLL|Unsigned Hex Long Long Key|8 bytes||||🟢
KCHR|Single ASCII Character Key|1 byte||✓|✓|🟢
KNAM|Four-Character Type Key|4 bytes||✓|✓|🟢
KRID|Key on Current Resource ID|0 bytes||✓|✓|🟢
KEYB|Begin Keyed Item for Previous CASE|0 bytes||✓|✓|🟢
KEYE|End of Keyed Item|0 bytes||✓|✓|🟢

### Alignment and Filler Field Types

Type|Description|Size|ResEdit|Resorcerer|Rezilla|ResKnife
----|-----------|----|-------|----------|-------|--------
AWRD|Align to 2-byte boundary|0 to 1|✓|✓|✓|🟢
ALNG|Align to 4-byte boundary|0 to 3|✓|✓|✓|🟢
AL08|Align to 8-byte boundary|0 to 7||✓|✓|🟢
AL16|Align to 16-byte boundary|0 to 15||✓|✓|🟢
FBYT|Fill Byte|1 byte|✓|✓|✓|🟢
FWRD|Fill Word|2 bytes|✓|✓|✓|🟢
FLNG|Fill Long|4 bytes|✓|✓|✓|🟢
Fnmm|Fill Bytes|$_nmm_ bytes||✓|✓|🟢

### Miscellaneous Graphic and System Field Types

Type|Description|Size|ResEdit|Resorcerer|Rezilla|ResKnife
----|-----------|----|-------|----------|-------|--------
RSID|Signed Resource ID Integer|2 bytes||✓|✓|🟢
CHAR|ASCII Character|1 byte|✓|✓|✓|🟢
TNAM|Type Name|4 bytes|✓|✓|✓|🟢
DATE|Macintosh System Date/Time (seconds)|4 bytes||✓|✓|🟢
MDAT|Modification Date/Time (seconds)|4 bytes||✓|✓|🟢
SCPC|MacOS System Script Code|2 bytes||✓|✓|🟡
LNGC|MacOS System Language Code|2 bytes||✓|✓|🟡
RGNC|MacOS System Region Code|2 bytes||✓|✓|🟡
PNT|QuickDraw Point|4 bytes||✓|✓|🟢
RECT|QuickDraw Rectangle|8 bytes|✓|✓|✓|🟢
COLR|QuickDraw Color RGB Triplet|6 bytes||✓|✓|🟢
WCOL|15-bit Color|2 bytes|||✓|🟢
LCOL|24-bit Color|4 bytes|||✓|🟢
CLUT|Color Lookup Table Hex Dump|any||✓||🔴
CODE|680x0 Disassembled Code Dump|any||✓||🟡

### Big and Little-Endian Parsing

Type|Description|Size|ResEdit|Resorcerer|Rezilla|ResKnife
----|-----------|----|-------|----------|-------|--------
BNDN|Use Big-Endian Data Parsing|0 bytes||✓||🟢
LNDN|Use Little-Endian Data Parsing|0 bytes||✓||🟢

### Symbolic Constants

Type|Description|Size|ResEdit|Resorcerer|Rezilla|ResKnife
----|-----------|----|-------|----------|-------|--------
CASE|Symbolic and/or Default Value|0 bytes||✓|✓|🟢
CASR|Symbolic Value Range|0 bytes||||🟢

### Cosmetic and Layout Control

Type|Description|Size|ResEdit|Resorcerer|Rezilla|ResKnife
----|-----------|----|-------|----------|-------|--------
DVDR|Divider Line with Comment|0 bytes||✓|✓|🟢
RREF|Static Resource Reference|0 bytes||||🟢
PACK|Combine Other Elements|0 bytes||||🟢

### Inserting or Deleting Data in Existing Resources

Type|Description|Size|ResEdit|Resorcerer|Rezilla|ResKnife
----|-----------|----|-------|----------|-------|--------
+BYT|Insert a Byte When Opening|1 byte||✓||🔴
+WRD|Insert a Word When Opening|2 bytes||✓||🔴
+LNG|Insert a Long When Opening|4 bytes||✓||🔴
+nmm|Insert Bytes When Opening|$_nmm_ bytes||✓||🔴
+PST|Insert a Pascal String When Opening|1 to 256||✓||🔴
+EST|Insert an Even Pascal String When Opening|2 to 256||✓||🔴
+CST|Insert a C String When Opening|1 or more||✓||🔴
-BYT|Delete a Byte When Closing|1 byte||✓||🔴
-WRD|Delete a Word When Closing|2 bytes||✓||🔴
-LNG|Delete a Long When Closing|4 bytes||✓||🔴
-nmm|Insert Bytes When Closing|$_nmm_ bytes||✓||🔴
-PST|Delete a Pascal String When Closing|1 to 256||✓||🔴
-EST|Delete an Even Pascal String When Closing|2 to 256||✓||🔴
-CST|Delete a C String When Closing|1 or more||✓||🔴

### Pre- and Post-Processing Data with Code Filters

Type|Description|Size|ResEdit|Resorcerer|Rezilla|ResKnife
----|-----------|----|-------|----------|-------|--------
FLTR|Declare Filtered Template (with comment)|0 bytes||✓||🔴
