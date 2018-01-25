#!/bin/sh
ret=0
for _FILE in vi-VN/*.po;
do
    msgfmt --check --output-file /dev/null --statistics ${_FILE};
    ret=$(( ret + $? ))
done
exit $ret
