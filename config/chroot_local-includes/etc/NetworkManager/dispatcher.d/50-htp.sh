#!/bin/bash

# Rationale: Tor needs a somewhat accurate clock to work, and for that
# HTP is currently the only practically usable solution when one wants
# to authenticate the servers providing the time. We then need to get
# the IPs of a bunch of HTTPS servers.

# However, since all DNS lookups are normally made through the Tor
# network, which we are not connected to at this point, we use the
# local DNS servers obtained through DHCP, if possible, or the OpenDNS
# ones otherwise.

# To limit fingerprinting possibilities, we do not want to send HTTP
# requests aimed at an IP-based virtualhost such as https://IP/, but
# rather to the usual hostname (e.g. https://www.eff.org/) as any
# "normal" user would do. Once we have got the HTTPS servers IPs, we
# write these to /etc/hosts so the system resolver knows about them.
# htpdate is then run, and we eventually remove the added entries from
# /etc/hosts.

# Note that all network operations (host, htpdate) are done with the
# htp user, who has an exception in the firewall configuration
# granting it direct access to the needed network ports.

# That's why we tell the htpdate script to drops priviledges and run
# as the htp user all operations but the actual setting of time, which
# has to be done as root.


### Init variables

LOG=/var/log/htpdate.log
DONE_FILE=/var/lib/live/htp-done
SUCCESS_FILE=/var/lib/live/htp-success

declare -a HTP_POOL
HTP_POOL=(
	'www.torproject.org'
	'mail.riseup.net'
	'encrypted.google.com'
	'ssl.scroogle.org'
)

BEGIN_MAGIC='### BEGIN HTP HOSTS'
END_MAGIC='### END HTP HOSTS'

if [[ -n "${DHCP4_DOMAIN_NAME_SERVERS}" ]]; then
	NAME_SERVERS="${DHCP4_DOMAIN_NAME_SERVERS}"
else
	NAME_SERVERS="208.67.222.222 208.67.220.220"
fi


### Exit conditions

# Run only when the interface is not "lo":
if [[ $1 = "lo" ]]; then
	exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [[ $2 != "up" ]]; then
	exit 0
fi

# Do not run if we already successed:
if [ -e "${SUCCESS_FILE}" ]; then
	exit 0
fi


### Delete previous state file
rm -f "${DONE_FILE}"


### Create log file

# The htp user needs to write to this file.
# The $LIVE_USERNAME user needs to read this file.
touch "${LOG}"
chown htp:nogroup "${LOG}"
chmod 644 "${LOG}"


### Run tails-htp-notify-user (the sooner, the better)

# Get LIVE_USERNAME
. /etc/live/config.d/username

export DISPLAY=':0.0'
export XAUTHORITY="`echo /var/run/gdm3/auth-for-${LIVE_USERNAME}-*/database`"
exec /bin/su -c /usr/local/bin/tails-htp-notify-user "${LIVE_USERNAME}" &


### Functions

log () {
	echo "$@" >> "${LOG}"
}

quit () {
	exit_code="$1"
	shift
	message="$@"

	cleanup_etc_hosts
	echo "$exit_code" >> "${DONE_FILE}"
	if [ $exit_code -eq 0 ]; then
		touch "${SUCCESS_FILE}"
	fi
	log "${message}"
	exit $exit_code
}

cleanup_etc_hosts() {
	log "Cleaning /etc/hosts"
	local tempfile
	tempfile=`mktemp -t nm-htp.XXXXXXXX`
	where=outside
	cat /etc/hosts | while read line ; do
		if [ "$where" = inside ]; then
			if [ "$line" = "$END_MAGIC" ]; then
				where=outside
			fi
		else
			if [ "$line" = "$BEGIN_MAGIC" ]; then
				where=inside
			else
				echo "$line" >> $tempfile
			fi
		fi
	done
	chmod 644 "$tempfile"
	mv "$tempfile" /etc/hosts
}


### Main

# Beware: this string is used and parsed in tails-htp-notify-user
log "HTP NetworkManager hook: here we go"
log "Will use these nameservers: ${NAME_SERVERS}"

echo "${BEGIN_MAGIC}" >> /etc/hosts

for HTP_HOST in ${HTP_POOL[*]} ; do
	DNS_QUERY_CMD=`for NS in ${NAME_SERVERS}; do
	               echo -n "|| host ${HTP_HOST} ${NS} ";
	               done | \
	               tail --bytes=+4`
	IP=$(sudo -u htp sh -c "${DNS_QUERY_CMD}" | \
	       grep "has address" | \
	       head -n 1 | \
	       cut -d ' ' -f 4)
	if [[ -z ${IP} ]]; then
		echo "${END_MAGIC}" >> /etc/hosts
		quit 17 "Failed to resolve ${HTP_HOST}"
	else
		echo "${IP}	${HTP_HOST}" >> /etc/hosts
	fi
done

echo "${END_MAGIC}" >> /etc/hosts

/usr/local/sbin/htpdate \
	-d \
	-l "${LOG}" \
	-a "`/usr/local/bin/getTorbuttonUserAgent`" \
	-f \
	-p \
	-u htp \
	${HTP_POOL[*]}
HTPDATE_RET=$?

quit ${HTPDATE_RET} "htpdate exited with return code ${HTPDATE_RET}"
