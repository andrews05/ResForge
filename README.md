# ResForge

![ResForge](https://github.com/andrews05/ResForge/raw/master/ResForge/Assets.xcassets/ResForge.appiconset/ResForge_128.png)

ResForge is a resource editor for macOS, capable of editing classic resource fork files and related formats. Based on [ResKnife](https://github.com/nickshanks/ResKnife) by Nicholas Shanks and Uli Kusterer, this derivative of the project has been rewritten for modern macOS systems.

### Features

* Supports both resource and data forks in the original resource file format, as well as experimental support for the new extended format defined by [Graphite](https://github.com/TheDiamondProject/Graphite).
* Hexadecimal editor, powered by [HexFiend](https://github.com/HexFiend/HexFiend).
* Template editor, supporting a wide array of [field types](https://github.com/andrews05/ResForge/tree/master/ResForge/Template%20Editor#template-editor).
* Template-driven bulk data view, with CSV import/export.
* Image editor, supporting 'PICT', 'PNG ', 'cicn' & 'ppat' resources, plus view-only support for a variety of icons and other bitmaps.
* Sound editor, supporting sampled 'snd ' resources.
* Sprite editor, supporting 'rlëD' resources used by EV Nova.
* Ship Animation editor, supporting 'shän' resources used by EV Nova.


## Getting Started

### System Requirements

ResForge is compatible with macOS 10.12 or later, including macOS 11. The universal binary runs natively on both 64-bit Intel and Apple Silicon.

### Installation

Download the latest version of ResForge from the [Releases](https://github.com/andrews05/ResForge/releases) page.

### Building

To build ResForge yourself you will need to have Xcode 12 or later installed.

Make sure to use the `--recurse-submodules` option when cloning the repository, or use `git submodule update --init` to initialise an existing copy.

### Plug-ins

ResForge includes a plug-in architecture, allowing custom editors to be created and distributed independently of the application itself. The specification is not currently documented but feel free to duplicate an existing plug-in, such as the hex editor, and work from there to create your own.


## Built With

* [Graphite](https://github.com/TheDiamondProject/Graphite) - Provides reading/writing of resource files, as well 'PICT', 'cicn' and 'ppat' resources. 
* [HexFiend](https://github.com/HexFiend/HexFiend) - Powers the hexadecimal editor.
* [CSV.swift](https://github.com/yaslab/CSV.swift) - Provides reading/writing of CSV files.


## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request


## License

Distributed under the MIT License. See `LICENSE` for more information.
