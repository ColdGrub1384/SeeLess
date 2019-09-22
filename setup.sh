#!/bin/bash

# Submodules

git submodule update --init --recursive

cd LibTerm

sh setup.sh

cd ../

# Cocoapods

pod install
