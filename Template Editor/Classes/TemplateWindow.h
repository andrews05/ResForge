#include "Template Editor.h"

typedef class TemplateWindow	TemplateWindow, *TemplateWindowPtr;
typedef class Element			Element, *ElementPtr;

/*** CONSTANTS ***/
const UInt32 kHeaderSignature		= FOUR_CHAR_CODE('head');
const UInt32 kLabelSignature		= FOUR_CHAR_CODE('labl');
const UInt32 kBooleanGroupSignature	= FOUR_CHAR_CODE('bool');
const UInt32 kRectGroupSignature	= FOUR_CHAR_CODE('rect');
const UInt32 kEditFieldSignature	= FOUR_CHAR_CODE('edit');
const UInt32 kHexDumpSignature		= FOUR_CHAR_CODE('hdmp');
const UInt32 kListCountSignature	= FOUR_CHAR_CODE('list');
const UInt32 kScrollbarSignature	= FOUR_CHAR_CODE('scrl');

/*** TEMPLATE WINDOW CLASS ***/
class TemplateWindow
{
	WindowRef	window;
	Handle		tmpl;
	UInt32		elementCount;
	ElementPtr	elements;
	Rect		bounds;		// the bounds of the previous control
	
public:
				TemplateWindow( WindowRef newWindow );
				~TemplateWindow( void );
	OSStatus	UseTemplate( Handle newTmpl );
	OSStatus	ParseData( Handle data );
private:
	OSStatus	ParseTemplate( void );
	OSStatus	CreateControls( void );
	OSStatus	ReadControls( void );
};

/*** TEMPLATE ELEMENT CLASS ***/
class Element
{
	Str255		label;
	UInt32		type;
//	need ControlHandle here (only one, can embed within)
	ElementPtr	next;
	
				Element( void );
	friend class TemplateWindow;
};

Boolean HandlesMatch( const Handle one, const Handle two );