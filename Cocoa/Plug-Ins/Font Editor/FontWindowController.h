#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

@interface FontWindowController : NSWindowController <ResKnifePluginProtocol>
{
	id <ResKnifeResourceProtocol>	resource;
	
	OSType arch;
	UInt16 numTables;
	UInt16 searchRange;
	UInt16 entrySelector;
	UInt16 rangeShift;
	NSMutableArray *headerTable;
}
- (void)loadFontFromResource;
- (IBAction)saveResource:(id)sender;
- (void)setTableData:(id <ResKnifeResourceProtocol>)tableResource;
- (void)openTable:(NSDictionary *)table inEditor:(BOOL)editor;
@end

/*	known Open Font Architectures (OFAs)

	true = TrueType (Mac)
	0x00010000 = TrueType (Windows)
	OTTO = OpenType
	typ1 = Type 1
*/

const OSType kOFATrueType		= 'true';
const OSType kOFAOpenType		= 'OTTO';
const OSType kOFAType1			= 'typ1';
const OSType kOFATrueTypeWindows = 0x00010000;

/*	known sfnt tables for all OFAs (TT, OT, T1)

	acnt = Accent attachment
	addg
	avar = Axis variation
	BASE  (Baseline adjustment)
	bdat = Bitmap data
	bhed = Bitmap font header
	bloc = Bitmap location
	bsln = Baseline
	CFF   (Type 1 glyph outlines)
	cmap = Character mapping
	cvar = CVT variation
	cvt  = Control value
	DSIG  (Digital signature)
	EBDT  (Embedded bitmap data)
	EBLC  (Embedded bitmap locator)
	EBSC = Embedded bitmap scaling control
	ENCO	[seen in Tekton Plus]
	fdsc = Font descriptor
	feat = Layout features
	fmtx = Font metrics
	FNAM	[seen in Tekton Plus]
	fpgm = Font program
	fvar = Font variations
	gasp = Grid-fitting and scan-conversion procedure
	glyf = Glyph outlines
	GPOS  (Glyph positioning)
	GSUB  (Glyph substitution)
	gvar = Glyph variations
	hdmx = Horizontal device metrics
	head = Font header
	HFMX	[seen in Tekton Plus]
	hhea = Horizontal header
	hmtx = Horizontal metrics
	hsty = Horizontal style
	just = Justification
	kern = Kerning
	lcar = Ligature caret
	loca = Glyph location indicies
	LTSH	"This table improves the performance of OpenType fonts with TrueType outlines. The table should be used if bit 2 or 4 of flags in 'head' is set. (Microsoft)" [seen in Cochin]
	maxp = Maximum profile
	mort = Metamorphosis
	morx = Extended metamorphosos
	name = Font names and other strings
	opbd = Optical bounds
	OS/2 = OS compatibility
	post = Glyph names & PostScript compatibility
	prep = Control value program
	prop = Properties
	trak = Tracking
	TYP1  (Type 1 glyph outlines) [seen in Tekton Plus]
	VDMX  (Vertical device metrics) [seen in Cochin]
	vhea = Vertical header
	vmtx = Vertical metrics
	Zapf = Glyph reference
*/

/* THESE C STRUCTS ARE JUST TO MAKE IT EASIER TO LOAD THE RESOURCE, AND HELP WITH DEBUGGING */

/* sfnt resource http://developer.apple.com/documentation/mac/Text/Text-253.html */
typedef struct
{
	unsigned short versionMajor;
	unsigned short versionMinor;
	unsigned short tableCount;
	unsigned short searchRange;
	unsigned short entrySelector;
	unsigned short rangeShift;
	struct
	{
		unsigned long tagname;
		unsigned long checksum;
		unsigned long offset;
		unsigned long length;
	} __attribute__ ((packed)) tables[0];
} __attribute__ ((packed)) sfnt_header;

/* name record http://developer.apple.com/documentation/mac/Text/Text-266.html */
typedef struct
{
	unsigned short format_selector; // always 0
	unsigned short record_count;	// number of name records
	unsigned short record_offset;   // the offset from the start of the table to the start of string storage
	struct
	{
		unsigned short platform_id;
		unsigned short platform_specific_id;
		unsigned short language_id;
		unsigned short name_id;
		unsigned short length;
		unsigned short offset;  // the offset from the start of storage area
	} __attribute__ ((packed)) names[0];
} __attribute__ ((packed)) name_table_header;

