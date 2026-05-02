#!/bin/sh
# Copyright 2022 Collabora Ltd.
# SPDX-License-Identifier: Zlib

set -eu

cd `dirname $0`/..

# Needed so sed doesn't report illegal byte sequences on macOS
export LC_CTYPE=C

tests=0
failed=0

ok () {
    tests=$(( tests + 1 ))
    echo "ok - $*"
}

not_ok () {
    tests=$(( tests + 1 ))
    echo "not ok - $*"
    failed=1
}

ref_major=$(sed -ne 's/^set(MAJOR_VERSION \([0-9]*\))$/\1/p' CMakeLists.txt)
ref_minor=$(sed -ne 's/^set(MINOR_VERSION \([0-9]*\))$/\1/p' CMakeLists.txt)
ref_micro=$(sed -ne 's/^set(MICRO_VERSION \([0-9]*\))$/\1/p' CMakeLists.txt)
ref_version="${ref_major}.${ref_minor}.${ref_micro}"

version=$(sed -ne 's/^#define VERSION "\([0-9\.]*\)"$/\1/p' game/Maelstrom.h)
if [ "$ref_version" = "$version" ]; then
	ok "Maelstrom.h VERSION $version"
else
	not_ok "Maelstrom.h VERSION $version disagrees with CMakeLists.txt $ref_version"
fi

for rcfile in Maelstrom.rc; do
    tuple=$(sed -ne 's/^ *FILEVERSION *//p' "$rcfile" | tr -d '\r')
    ref_tuple="${ref_major},${ref_minor},${ref_micro},0"

    if [ "$ref_tuple" = "$tuple" ]; then
        ok "$rcfile FILEVERSION $tuple"
    else
        not_ok "$rcfile FILEVERSION $tuple disagrees with CMakeLists.txt $ref_tuple"
    fi

    tuple=$(sed -ne 's/^ *PRODUCTVERSION *//p' "$rcfile" | tr -d '\r')

    if [ "$ref_tuple" = "$tuple" ]; then
        ok "$rcfile PRODUCTVERSION $tuple"
    else
        not_ok "$rcfile PRODUCTVERSION $tuple disagrees with CMakeLists.txt $ref_tuple"
    fi

    tuple=$(sed -Ene 's/^ *VALUE "FileVersion", "([0-9, ]*)"\r?$/\1/p' "$rcfile" | tr -d '\r')
    ref_tuple="${ref_major}, ${ref_minor}, ${ref_micro}, 0"

    if [ "$ref_tuple" = "$tuple" ]; then
        ok "$rcfile FileVersion $tuple"
    else
        not_ok "$rcfile FileVersion $tuple disagrees with CMakeLists.txt $ref_tuple"
    fi

    tuple=$(sed -Ene 's/^ *VALUE "ProductVersion", "([0-9, ]*)"\r?$/\1/p' "$rcfile" | tr -d '\r')

    if [ "$ref_tuple" = "$tuple" ]; then
        ok "$rcfile ProductVersion $tuple"
    else
        not_ok "$rcfile ProductVersion $tuple disagrees with CMakeLists.txt $ref_tuple"
    fi
done

version=$(sed -ne 's/^ *versionName "\([0-9\.]*\)"$/\1/p' android-project/app/build.gradle)
if [ "$ref_version" = "$version" ]; then
	ok "build.gradle VERSION $version"
else
	not_ok "build.gradle VERSION $version disagrees with CMakeLists.txt $ref_version"
fi

marketing=$(sed -Ene 's/.*MARKETING_VERSION = (.*);/\1/p' Xcode/Maelstrom.xcodeproj/project.pbxproj)

ref="$ref_version
$ref_version"

if [ "$ref" = "$marketing" ]; then
    ok "project.pbxproj MARKETING_VERSION is consistent"
else
    not_ok "project.pbxproj MARKETING_VERSION is inconsistent, expected $ref, got $marketing"
fi

echo "1..$tests"
exit "$failed"
