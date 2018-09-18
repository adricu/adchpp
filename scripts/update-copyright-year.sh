#!/bin/bash

# Update the copyright year of all ADCH++ files.

# Arguments:
# 	- Old year.
# 	- New year.

# Requirements: A Bash Shell with GNU extensions (Cygwin on Windows works).

OLD_YEAR="$1"
NEW_YEAR="$2"

if [[ -z $OLD_YEAR ]]; then
	echo Argument missing: Old year.
	exit 1
fi
if [[ -z $NEW_YEAR ]]; then
	echo Argument missing: New year.
	exit 1
fi

echo Replacing from $OLD_YEAR to $NEW_YEAR...

find ../License.txt ../adchpp ../adchppd ../docs ../plugins/Bloom/src ../plugins/Script/src \
	-type f \( -name "License.txt" -o -name "*.h" -o -name "*.cpp" -o -name "*.txt" -o -name "*.py" -o -name "*.rc" \) \
	-exec sed -i -r "s/([Cc]opyright )(\\([Cc]\\) )?([0-9]{4}-)?$OLD_YEAR([ ,A-Za-z]*Jacek Sieka)/\1\2\3$NEW_YEAR\4/g" '{}' \;

echo Done.
