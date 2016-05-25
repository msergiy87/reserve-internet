#!/bin/bash
#set -x

MAIN_GW="11.11.11.1"
RESERVE_GW="22.22.22.2"

MAIN_IP="11.11.11.33"
RESERVE_IP="22.22.22.44"

MAIN_PEER="telrad"

# Get the current router
CURRENT_GW=$(ip route show 0.0.0.0/0 | awk '{ print $3}')

LOG_FILE="/var/log/debug_rezerv_inet.log"

if [ ! -f /etc/logrotate.d/asterisk-debug_rezerv_inet ]
then
	cat > /etc/logrotate.d/asterisk-debug_rezerv_inet <<- _EOF_
	/var/log/debug_rezerv_inet.log {
	     daily
	     missingok
	     rotate 12
	     compress
	     delaycompress
	     minsize 1048576
	     notifempty
	     create 640 root root
	}
	_EOF_
fi

echo "" >> $LOG_FILE
echo "RUN SCRIPT AT $(date +%d-%m-%Y_%H:%M:%S)" >> $LOG_FILE
echo "CURRENT gateway $CURRENT_GW" >> $LOG_FILE

#=========================================================
#pgrep -l -u root asterisk > /dev/null 2>&1
#if [ $? -ne 0 ]
#then
#	echo "There are no asterisk process present. Exit" >> $LOG_FILE
#	exit 113
#fi

IS_REGISTRY=$(asterisk -rx "sip show peer $MAIN_PEER" | grep Status | awk '{print $3}')

if [ "OK" = "$IS_REGISTRY" ] && [ "$MAIN_GW" = "$CURRENT_GW" ]
then
	echo "All is fine, SIP chaneel ALIVE and Uteam is current" >> $LOG_FILE
	echo "END SCRIPT AT $(date +%d-%m-%Y_%H:%M:%S)" >> $LOG_FILE
	exit 0

elif [ "OK" != "$IS_REGISTRY" ]
then 
	echo "SIP chaneel is DEAD!" >> $LOG_FILE
fi
#=========================================================

# Check if the main router is pinged
if ping -c 4 -I $MAIN_IP 8.8.8.8 > /dev/null 2>&1
then
	echo "Uteam is working (pinging)" >> $LOG_FILE

	if [ "$CURRENT_GW" = "$MAIN_GW" ]
	then
		echo "Uteam is current. Problems with registration. Exit" >> $LOG_FILE
		echo "END SCRIPT AT $(date +%d-%m-%Y_%H:%M:%S)" >> $LOG_FILE
		exit 113
	else
		echo "MAIN not Current, switch to Uteam" >> $LOG_FILE
		#=====================================================
		# Check if we have active calls
		ACTIVE_CALLS=$(asterisk -rx "core show channels" | grep "active call" | awk '{print $1}')

		if [ 1 -le "$ACTIVE_CALLS" ]
		then
			echo "There are $ACTIVE_CALLS current calls. Switch to Uteam delayed. Exit" >> $LOG_FILE
			echo "END SCRIPT AT $(date +%d-%m-%Y_%H:%M:%S)" >> $LOG_FILE
			exit 113
		fi
		#=====================================================
		ip route replace default via $MAIN_GW
		#/etc/init.d/asterisk reload
		#/etc/init.d/asterisk stop
		#cp -f /etc/asterisk/copy/pjsip.transports.conf.uteam  /etc/asterisk/pjsip.transports.conf
		#cp -f /etc/asterisk/copy/sip_general_additional.conf.uteam /etc/asterisk/sip_general_additional.conf
		#/etc/init.d/asterisk start
		echo "Default route switch to Uteam: $MAIN_GW" >> $LOG_FILE
		echo "END SCRIPT AT $(date +%d-%m-%Y_%H:%M:%S)" >> $LOG_FILE
		exit 0
	fi
else
	echo "Uteam not working (not pinging)" >> $LOG_FILE

	if [ "$CURRENT_GW" = "$RESERVE_GW" ]
	then
		echo "Discovery is Current. Exit" >> $LOG_FILE
		echo "END SCRIPT AT $(date +%d-%m-%Y_%H:%M:%S)" >> $LOG_FILE
		exit 0
	else
		echo "Discovery not Current. switch to Discovery" >> $LOG_FILE
		#=====================================================
		# We shouldn't change GW if reserve channel is unavailable
		if ! ping -c 4 -I $RESERVE_IP 8.8.8.8 > /dev/null 2>&1
		then
			echo "Discovery is unavailable (not pingigng). Exit" >> $LOG_FILE
			echo "END SCRIPT AT $(date +%d-%m-%Y_%H:%M:%S)" >> $LOG_FILE
			exit 113
		fi
		#=====================================================
		ip route replace default via $RESERVE_GW
		#/etc/init.d/asterisk reload
		#/etc/init.d/asterisk stop
		#cp -f /etc/asterisk/copy/pjsip.transports.conf.disc  /etc/asterisk/pjsip.transports.conf
		#cp -f /etc/asterisk/copy/sip_general_additional.conf.disc /etc/asterisk/sip_general_additional.conf
		#/etc/init.d/asterisk start
		echo "Default route switch to Discovery: $RESERVE_GW" >> $LOG_FILE
		echo "END SCRIPT AT $(date +%d-%m-%Y_%H:%M:%S)" >> $LOG_FILE
		exit 0
	fi
fi
