#!/bin/sh

cd /web/cpandeps`cat dev_build`.cantrell.org.uk
find db -name \*yml -mtime +6 -exec rm -fv {} \;
