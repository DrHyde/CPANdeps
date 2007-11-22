#!/bin/sh

cd /web/cpandeps-dev.cantrell.org.uk
find db -name \*yml -mtime +6 -exec rm -fv {} \;

