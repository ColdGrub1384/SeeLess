![](https://github.com/ColdGrub1384/SeeLess/raw/master/SeeLess/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5%402x.png)

# SeeLess

[![Download on the App Store](https://pisth.github.io/appstorebadge.svg)](https://apps.apple.com/us/app/seeless-c-compiler/id1481018071?uo=4)

<img src="https://seeless.app/assets/screenshot/Screenshot.png" width=300px>

SeeLess is a C IDE for iOS that integrates with LibTerm. SeeLess allows you to code commands with C and install them in LibTerm.

The compiler used to compile commands is `clang`. `clang` generates bitcode with `-S -emit-llvm` that can be executed with `lli` command. Also contains `llvm-link` so multiple objects can be linked into one "executable".

This app consists in the iOS system file browser for browsing projects. Projects are packages with C sources and configuration files.

## Compiling

To compile, run `setup.sh` and build the app from `SeeLess.xcworkspace`.
