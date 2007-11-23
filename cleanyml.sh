#!/bin/sh

DIR=`echo $0|sed 's/\/cleanyml.sh//'`

cd $DIR
find db -name \*yml -mtime +6 -exec rm -fv {} \;
