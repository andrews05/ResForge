#if defined(__APPLE_CC__)		// compiling with gcc
	#include <Carbon/Carbon.r>
#else							// compiling with CodeWarrior, __MWERKS__
	#include <Carbon.r>
#endif

/*** FILE MENU ***/
resource 'MENU' (2001)
{
	2001,
	textMenuProc,
	0xFFFFFFFF,
	enabled,
	"Rectangle Style",
	{
		"Bottom Right", noIcon, noKey, noMark, plain,
		"Width & Height", noIcon, noKey, noMark, plain,
	}
};

resource 'xmnu' (2001, purgeable)
{
	versionZero
	{
		{
			dataItem { 'rela', kMenuNoModifiers, currScript, 0, 0, noHierID, sysFont, naturalGlyph },
			dataItem { 'abso', kMenuNoModifiers, currScript, 0, 0, noHierID, sysFont, naturalGlyph }
		}
	};
};