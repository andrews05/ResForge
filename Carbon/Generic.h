// abbreviations
#define null	NULL
#define	qdb		qd.screenBits.bounds

// Easier API call names
#define GetWindowRefCon( window )				(long)		GetWRefCon( window )
#define SetWindowRefCon( window, refcon )					SetWRefCon( window, refcon )
#define GetWindowTitle( window, string )					GetWTitle( window, string )
#define SetWindowTitle( window, name )						SetWTitle( window, name )
#define InvalidateRect( bounds )							InvalRect( bounds )
#define InvalidateWindowRect( window, bounds )	(OSStatus)	InvalWindowRect( window, bounds )
#define RectToRegion( region, rect )						RectRgn( region, rect )
#define NewPoint()								(Point)		{ 0, 0 }
#define SetPoint( point, x, y )								SetPt( point, x, y )
#define HilightColour( colour )								HiliteColor( colour )
#define GetPortHilightColour( window, colour )				GetPortHiliteColor( window, colour )
