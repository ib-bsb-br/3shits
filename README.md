Welcome to the TreeSheets productivity tool!
============================================

<p align="center">
 <img width="607" height="498" alt="image" src="https://github.com/user-attachments/assets/9cabfa45-592b-4f03-b4e3-ed5c1c2ee4c7" />
</p>


TreeSheets ([https://strlen.com/treesheets/](https://strlen.com/treesheets/)) is an Open Source Free Form Data Organizer that leverages the power of hierarchical spreadsheets. Hierarchical spreadsheets serve as a great replacement for spreadsheets, mind mappers, outliners, PIMs, text editors and small databases.

Suitable for any kind of data organization, such as todo lists, calendars, project management, brainstorming, organizing ideas, planning, requirements gathering, presentation of information, etc.

It's like a spreadsheet, immediately familiar, but much more suitable for complex data because it's hierarchical.
It's like a mind mapper, but more organized and compact.
It's like an outliner, but in more than one dimension.
It's like a text editor, but with structure.

Grid semantics and movement
---------------------------
Within any single grid, sibling cells do have meaningful positional relationships:

- A cell's row and column define its address in that grid (like `column x, row y`).
- Moving a sibling to a different row or column changes its structural meaning, because selection,
  insertion, deletion, sorting, export, and scripting all use row/column coordinates.
- Siblings share the same parent grid, but that does **not** make them interchangeable by default.

The implementation of movement matters too:

- `CTRL+LEFT|RIGHT|UP|DOWN` moves a selection by swapping whole cell objects inside the grid, not by
  erasing one cell and rewriting only the visible text somewhere else.
- Because the whole cell moves, its attached state moves with it too: text, colors, style bits,
  image, note, and any subgrid all stay attached to that cell as it changes position.
- In other words, ordinary cell movement is positional relocation of the actual cell payload, not a
  text-only copy/delete operation.

`Hierarchy Swap` (`F8`) is different:

- It is not a simple left/right/up/down move inside one flat sibling set.
- Instead, it restructures the tree by promoting a matching cell upward, rebuilding the former
  parent chain as nested children under that promoted cell, deleting emptied containers, and merging
  with same-named cells when needed.
- Since this operation works by restructuring cells and their attached subgrids, it preserves
  associated cell data as part of that structural transformation rather than treating the cell as
  plain text.

So, in TreeSheets, sibling placement is meaningful, ordinary movement relocates the whole cell, and
`Hierarchy Swap` performs a higher-level hierarchy rewrite rather than a simple in-place sibling
swap.

Community
---------
If you like, you are kindly invited to join the [Discord channel](https://discord.gg/HAfKkJz) and 
the [Google group](https://groups.google.com/group/treesheets) for discussion.

Installation
------------

Pre-built binaries for Windows, macOS (Darwin) and Debian-based Linux distributions are available at the
[Release section](https://github.com/aardappel/treesheets/releases). 

Please note that the packages for Debian-based distributions provided are built on `ubuntu-latest` used by [GitHub Actions Runner](https://github.com/actions/runner-images). They could also be installed on other Debian-based distributions depending on whether the required dependency packages are available.

If you use Flatpak, you can install [TreeSheets from Flathub](https://flathub.org/apps/com.strlen.TreeSheets).

Source Code
-----------
This repository contains all the files needed to build TreeSheets for various platforms.

### License

TreeSheets has been licensed under the ZLIB license (see ZLIB_LICENSE.txt).

![Workflow status](https://github.com/aardappel/treesheets/actions/workflows/build.yml/badge.svg)

### Structure

`src` contains all source code. The code is dense, terse, and with few comments, typical for a codebase that was never
intended to be used by more than one person (me). On the positive side, you'll find the code very small and simple,
with all functionality easy to find and only in one place (no copy pasting or over-engineering). Enjoy.

`TS` is the folder that contains all user-facing files, typically the build process results in an executable to be put
in the root of this folder, and distributing to users is then a matter of giving them this folder.

`TODO.txt` is the random notes I kept on ideas of myself and others on what future features could be added.


Building
--------
This project uses CMake to enable compilation on various platforms and CPack on top of it to package the produced binaries. The build, installation and packaging instructions are within `CMakeLists.txt`.
Please note that you are responsible to know how to use compilers and C++, the hints below are all the help we will give you for building TreeSheets:

1. Clone this repository

```sh
git clone https://github.com/aardappel/treesheets
```

2. Change the working directory to the working tree

```sh
cd treesheets
```

3. Steps for building and installation/packaging for binary distribution

| Step | Command | Windows | macOS | Linux |
| ---- | ------- | ------- | ----- | ----- |
| 3.1 Configure the build system | `cmake -S . -B _build -DCMAKE_BUILD_TYPE=Release` | needs Visual Studio C++ compiler for succesful compilation | | |
| 3.2 Build and package for binary distribution | `cmake --build _build --target package -j` | creates a ZIP archive for portable usage and a Nullsoft installer | creates a disk image for Drag and Drop installation | creates a binary Debian package |
| or |
| 3.2 Build only | `cmake --build _build -j` | Append `--config Release` | | |
| 3.3 Install | `cmake --install _build` | | Append `--prefix <directory>` to specify another installation root for the bundle | usually requires root privileges, e.g. run this command with `sudo` |

If you do not have `wxWidgets` installed, you may want to set `wxBUILD_INSTALL` and `wxBUILD_SHARED` to off in the build configuration. This ensures a TreeSheets build with wxWidgets libraries statically linked in.

### Debian 11 ARM64 / RK3588 deployment helper

For constrained Debian 11 ARM64 systems (for example RK3588 boards), this repository also includes an optional deployment helper script:

```sh
./treesheets-deploy.sh
```

This script combines:

- the normal CMake/CPack packaging flow;
- verbose build logs persisted to disk for easier diagnosis of hidden parallel-build errors;
- a verified Lobster charconv patch fallback if the older-toolchain CMake workaround is not sufficient;
- automatic retry with `-DENABLE_LOBSTER=OFF` if a Lobster-enabled build fails, so package generation can still complete on older toolchains;
- optional system-wide package installation and optional kiosk auto-start setup.

Note: CMake already contains a guarded GCC `< 11` Lobster compatibility patch. The script complements that with stronger diagnostics and a practical end-to-end deployment path for Debian 11 ARM64 targets.

Contributing
------------
I welcome contributions, especially in the form of neatly prepared pull requests. The main thing to keep in mind when
contributing is to keep as close as you can to both the format and the spirit of the existing code, even if it goes
against the grain of how you program normally. That means not only using the same formatting and naming conventions
(which should be easy), but the same non-redundant style of code (no under-engineering, e.g. copy pasting,
and no over engineering, e.g. needless abstractions).

Also be economic in terms of features: treesheets tries to accomplish a lot with few features, additional user
interface elements (even menu items) have a cost, and features that are only useful for very few people should
probably not be in the master branch. Needless to say, performance is important too. When in doubt, ask me :)

Try to keep your pull requests small (don't bundle unrelated changes) and make sure you've done extensive testing
before you submit, preferrably on multiple platforms.
