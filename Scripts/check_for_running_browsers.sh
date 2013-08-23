#!/bin/bash
# A script to check if browsers are running
CODE=0

echo "starting script check_for_running_browsers">> ~/.cim_install_log
ps ux | grep '[C]hrome'>> /dev/null
let "CODE = $CODE + $?"
ps ux | grep '[S]afari'>> /dev/null
let "CODE = $CODE + $?"
ps ux | grep '[F]irefox'>> /dev/null
let "CODE = $CODE + $?"
echo $CODE>> ~/.cim_install_log

#echo "send omniture call">> ~/.cim_install_log
#curl http://www.google.com>> ~/.cim_install_log

if test $CODE -lt 3
then
	exit 1
else
	exit 0
fi