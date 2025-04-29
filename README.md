# ResForge

![ResForge](https://github.com/andrews05/ResForge/raw/master/ResForge/Assets.xcassets/ResForge.appiconset/ResForge_128.png)

ResForge is a resource editor for macOS, capable of editing classic resource fork files and related formats. Based on [ResKnife](https://github.com/nickshanks/ResKnife) by Nicholas Shanks and Uli Kusterer, this derivative of the project has been rewritten for modern macOS systems.


## Installation

Download the latest version of ResForge from the [Releases](https://github.com/andrews05/ResForge/releases) page.

ResForge is compatible with macOS 10.15 or later and runs natively on both 64-bit Intel and Apple Silicon.


## Features

* Hexadecimal editor, powered by [HexFiend](https://github.com/HexFiend/HexFiend).
* Template editor, supporting a wide array of [field types](https://github.com/andrews05/ResForge/tree/master/Plugins/Sources/TemplateEditor#template-editor).
  * User-defined templates, loaded automatically from resource files in `~/Library/Application Support/ResForge/`.
  * Template-driven bulk data view, with CSV import/export.
  * Generic binary file editor, via the `Open with Template…` menu item.
* Image editor, supporting 'PICT', 'PNG ', 'PNGf', 'cicn' & 'ppat' resources, plus view-only support for a variety of icons and other bitmaps.
* Sound editor, supporting sampled 'snd ' resources.
* Dialog editor, supporting 'DITL' resources.
* Menu editor, supporting 'MENU', 'CMNU' & 'cmnu' resources.
* Tools for EV Nova, including powerful templates for all types and a number of graphical editors.

### Supported File Formats

* Macintosh resource format, in either resource fork or data fork.
* Rez format, used by EV Nova.
* Extended resource format, defined by [Graphite](https://github.com/TheDiamondProject/Graphite).
* MacBinary encoded resource fork.
* AppleSingle/AppleDouble encoded resource fork.


## Built With

* [HexFiend](https://github.com/HexFiend/HexFiend) - Powers the hexadecimal editor.
* [CSV.swift](https://github.com/yaslab/CSV.swift) - Provides reading/writing of CSV files.
* [swift-parsing](https://github.com/pointfreeco/swift-parsing) - Provides parsing of custom DSLs.


## Similar Projects

* [resource_dasm](https://github.com/fuzziqersoftware/resource_dasm) - CLI tools for disassembling resource files.


## License

Distributed under the MIT License. See `LICENSE` for more information.
