#!/bin/sh
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

$SCRIPT_DIR/parsealliances.pl $1
$SCRIPT_DIR/parseplanets.pl $1
$SCRIPT_DIR/parsegalaxies.pl $1
