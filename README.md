# ResKnife

ResKnife is a resource editor for macOS, capable of editing classic resource fork files and related formats. [Originally created](https://github.com/nickshanks/ResKnife) by Nicholas Shanks and Uli Kusterer, this fork of the project has been rewritten for modern macOS systems.

### Features

* Supports both resource and data forks in the original resource file format, as well as experimental support for the new extended format defined by [Graphite](https://github.com/TheDiamondProject/Graphite).
* Hexadecimal editor, powered by [HexFiend](https://github.com/HexFiend/HexFiend).
* Template editor, supporting a wide array of [field types](https://github.com/andrews05/ResKnife/tree/master/Plug-Ins/Template%20Editor).
* Image editor, supporting 'PICT', 'PNG ', 'cicn' & 'ppat' resources, plus view-only support for a variety of icons and other bitmaps.
* Sound editor, supporting sampled 'snd ' resources.
* Sprite editor, supporting 'rlëD' resources used by EV Nova.


## Getting Started

### System Requirements

ResKnife is compatible with macOS 10.11 or later, including macOS 11. The universal binary runs natively on both 64-bit Intel and Apple Silicon.

### Installation

Download the latest version of ResKnife from the [Releases](https://github.com/andrews05/ResKnife/releases) page.

### Building

To build ResKnife yourself you will need to have Xcode 12 or later installed.

Make sure to use the `--recurse-submodules` option when cloning the repository, or use `git submodule update --init` to initialise an existing copy.

### Plug-ins

ResKnife includes a plug-in architecture, allowing custom editors to be created and distributed independently of the application itself. The specification is not currently documented but feel free to duplicate an existing plug-in, such as the hex editor, and work from there to create your own plug-in.


## Built With

* [Graphite](https://github.com/TheDiamondProject/Graphite) - Provides ResKnife's reading/writing of resource files, as well 'PICT', 'cicn' and 'ppat' resources. 
* [HexFiend](https://github.com/HexFiend/HexFiend) - Powers ResKnife's hexadecimal editor.


## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request


## License

Distributed under the MIT License. See `LICENSE` for more information.
