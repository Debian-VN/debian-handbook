#!/bin/sh
ret=0
for _FILE in vi-VN/*.po;
do
    echo "+${_FILE}"
    msgfmt --check --output-file /dev/null --statistics ${_FILE}
    ret=$(( ret + $? ))
done
exit $ret
