# SeeLess

SeeLess is a C IDE for iOS that integrates with LibTerm. SeeLess allows you to code commands with C and install them in LibTerm.

The compiler used to compile commands is `clang`. `clang` generates bitcode with `-S -emit-llvm` that can be executed with `lli` command. Also contains `llvm-link` so multiple objects can be linked into one "executable".

This app consists in the iOS system file browser for browsing projects. Projects are packages with C sources and configuration files.

## Compiling

To compile, run `setup.sh` and build the app from `SeeLess.xcworkspace`.
