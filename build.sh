#!/usr/bin/env bash

ROOTDIR=$(pwd)
SRCDIR=$ROOTDIR/src

PROGRAM=templater

ODINFLAGS="-warnings-as-errors -debug"

odin build $SRCDIR $ODINFLAGS -out:$PROGRAM

EXIT=$?
if [[ "$EXIT" != "0" ]]; then
  exit $EXIT
fi

if [[ -n "$1" ]]; then
  if [[ "run" = "$1" ]]; then
    ./$PROGRAM
  fi
fi
