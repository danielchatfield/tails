#!/bin/bash

# Rationale: Tor needs a somewhat accurate clock to work, and for that
# HTP is currently the only practically usable solution when one wants
# to authenticate the servers providing the time. We then need to get
# the IPs of a bunch of HTTPS servers.

# However, since all DNS lookups are normally made through the Tor
# network, which we are not connected to at this point, we use the
# local DNS servers obtained through DHCP if possible, or the OpenDNS
# ones, else.

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

# Run only when the interface is not "lo":
if [[ $1 = "lo" ]]; then
   exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [[ $2 != "up" ]]; then
	exit 0
fi

LOG=/var/log/nm-htp.log
HTPDATE_LOG=/var/log/htpdate.log
DONE_FILE=/var/lib/live/htp-done

if [ -e "${DONE_FILE}" ]; then
   exit 0
fi

# Get LIVE_USERNAME
. /etc/live/config.d/username

export DISPLAY=':0.0'
exec /bin/su -c /usr/local/bin/tails-htp-notify-user "${LIVE_USERNAME}" &

declare -a HTP_POOL
HTP_POOL=(
	'www.torproject.org'
	'mail.riseup.net'
	'www.google.com'
	'ssl.scroogle.org'
)

BEGIN_MAGIC='### BEGIN HTP HOSTS'
END_MAGIC='### END HTP HOSTS'

if [[ -n "${DHCP4_DOMAIN_NAME_SERVERS}" ]]; then
	NAME_SERVERS="${DHCP4_DOMAIN_NAME_SERVERS}"
else
	NAME_SERVERS="208.67.222.222 208.67.220.220"
fi

echo "Will use these nameservers: ${NAME_SERVERS}" >>$LOG

cleanup_etc_hosts() {
	echo "Cleaning /etc/hosts" >>$LOG
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
		echo "Failed to resolve ${HTP_HOST}" >>$LOG
		echo "${END_MAGIC}" >> /etc/hosts
		cleanup_etc_hosts
		exit 17
	else
		echo "${IP}	${HTP_HOST}" >> /etc/hosts
	fi
done

echo "${END_MAGIC}" >> /etc/hosts

touch "${HTPDATE_LOG}"
chown htp:nogroup "${HTPDATE_LOG}"
chmod 600 "${HTPDATE_LOG}"

/usr/local/sbin/htpdate \
	-d \
	-l "${HTPDATE_LOG}" \
	-a "`/usr/local/bin/getTorbuttonUserAgent`" \
	-f \
	-p \
	-u htp \
	${HTP_POOL[*]}

HTPDATE_RET=$?
echo "htpdate exited with return code ${HTPDATE_RET}" >>$LOG

cleanup_etc_hosts

touch "${DONE_FILE}"

exit ${HTPDATE_RET}
