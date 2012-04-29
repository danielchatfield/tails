#!/bin/sh

# Rationale: Tor needs a somewhat accurate clock to work.
# If the clock is wrong enough to prevent it from opening circuits,
# we set the time to the middle of the valid time interval found
# in the Tor consensus, and we restart it.
# In any case, we use HTP to ask more accurate time information to
# a few authenticated HTTPS servers.


### Init variables

TORDATE_DIR=/var/run/tordate
TORDATE_DONE_FILE=${TORDATE_DIR}/done
TOR_DIR=/var/lib/tor
TOR_CONSENSUS=${TOR_DIR}/cached-consensus
TOR_UNVERIFIED_CONSENSUS=${TOR_DIR}/unverified-consensus
TOR_UNVERIFIED_CONSENSUS_HARDLINK=${TOR_UNVERIFIED_CONSENSUS}.bak
TOR_DESCRIPTORS=${TOR_DIR}/cached-descriptors
INOTIFY_TIMEOUT=60
DATE_RE='[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]'
VERSION_FILE=/etc/amnesia/version

# Get LIVE_USERNAME
. /etc/live/config.d/username.conf

### Exit conditions

# Run only when the interface is not "lo":
if [ "$1" = "lo" ]; then
	exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [ "$2" != "up" ]; then
	exit 0
fi

# Do not run twice
if [ -e "$TORDATE_DONE_FILE" ]; then
	exit 0
fi


### Create status directory
install -o root -g root -m 0755 -d ${TORDATE_DIR}


### Functions

log() {
	logger -t time "$@"
}

notify_user() {
	local summary="$1"
	local body="$2"

	if [ -n "$3" ]; then
		timeout_args='--expire-time=$3'
	fi
	export DISPLAY=':0.0'
	export XAUTHORITY="`echo /var/run/gdm3/auth-for-${LIVE_USERNAME}-*/database`"
	exec /bin/su -c "notify-send ${timeout_args} \"${summary}\" \"${body}\"" "${LIVE_USERNAME}" &
}

tor_is_working() {
	[ -e $TOR_DESCRIPTORS ]
}

has_consensus() {
	local files="${TOR_CONSENSUS} ${TOR_UNVERIFIED_CONSENSUS}"

	if [ $# -ge 1 ]; then
		files="$@"
	fi
	grep -qs "^valid-until ${DATE_RE}"'$' ${files}
}

has_only_unverified_consensus() {
	[ ! -e ${TOR_CONSENSUS} ] && has_consensus ${TOR_UNVERIFIED_CONSENSUS}
}

wait_for_tor_consensus_helper() {
	tries=0
	while ! has_consensus && [ $tries -lt 5 ]; do
		inotifywait -q -t 30 -e close_write -e moved_to ${TOR_DIR} || log "timeout"
		tries=$(expr $tries + 1)
	done

	# return some kind of success measurement
	has_consensus
}

wait_for_tor_consensus() {
	log "Waiting for a Tor consensus file to contain a valid time interval"
	if ! has_consensus && ! wait_for_tor_consensus_helper; then
		log "Unsuccessfully waited for Tor consensus, restarting Tor and retrying."
		service tor restart
	fi
	if ! has_consensus && ! wait_for_tor_consensus_helper; then
		log "Unsuccessfully retried waiting for Tor consensus, aborting."
	fi
	if has_consensus; then
		log "A Tor consensus file now contains a valid time interval."
	else
		log "Waited for too long, let's stop waiting for Tor consensus."
		# FIXME: gettext-ize
		notify_user "Synchronizing the system's clock" \
			"Could not fetch Tor consensus."
		exit 2
	fi
}

wait_for_working_tor() {
	log "Waiting for Tor to be working (i.e. cached descriptors exist)..."
	while ! tor_is_working; do
		inotifywait -q -t ${INOTIFY_TIMEOUT} -e close_write -e moved_to ${TOR_DIR} || log "timeout"
	done
	log "Tor is now working."
}

date_points_are_sane() {
	local vstart="$1"
	local vend="$2"

	vendchk=$(date -ud "${vstart} -0300" +'%F %T')
	[ "${vend}" = "${vendchk}" ]
}

time_is_in_valid_tor_range() {
	local curdate="$1"
	local vstart="$2"

	vendcons=$(date -ud "${vstart} -0230" +'%F %T')
	order="${vstart}
${curdate}
${vendcons}"
	ordersrt=$(echo "${order}" | sort)

	[ "${order}" = "${ordersrt}" ]
}

restart_tor() {
	if service tor status >/dev/null; then
		log "Restarting Tor service"
		service tor restart
	fi
}

maybe_set_time_from_tor_consensus() {
	local consensus=${TOR_CONSENSUS}

	if has_only_unverified_consensus \
	   && ln -f ${TOR_UNVERIFIED_CONSENSUS} ${TOR_UNVERIFIED_CONSENSUS_HARDLINK}; then
		consensus=${TOR_UNVERIFIED_CONSENSUS_HARDLINK}
		log "We do not have a Tor verified consensus, let's use the unverified one."
	fi

	log "Waiting for the chosen Tor consensus file to contain a valid time interval..."
	while ! has_consensus ${consensus}; do
		inotifywait -q -t ${INOTIFY_TIMEOUT} -e close_write -e moved_to ${TOR_DIR} || log "timeout"
	done
	log "The chosen Tor consensus now contains a valid time interval, let's use it."


	# Get various date points in Tor's format, and do some sanity checks
	vstart=$(sed -n "/^valid-after \(${DATE_RE}\)"'$/s//\1/p; t q; b; :q q' ${consensus})
	vend=$(sed -n "/^valid-until \(${DATE_RE}\)"'$/s//\1/p; t q; b; :q q' ${consensus})
	vmid=$(date -ud "${vstart} -0130" +'%F %T')
	log "Tor: valid-after=${vstart} | valid-until=${vend}"

	if ! date_points_are_sane "${vstart}" "${vend}"; then
		log "Unexpected valid-until: [${vend}] is not [${vstart} + 3h]"
		return
	fi

	curdate=$(date -u +'%F %T')
	log "Current time is ${curdate}"

	if time_is_in_valid_tor_range "${curdate}" "${vstart}"; then
		log "Current time is in valid Tor range"
		return
	fi

	log "Current time is not in valid Tor range, setting to middle of this range: [${vmid}]"
	date -us "${vmid}" 1>/dev/null

	# Tor is unreliable with picking a circuit after time change
	restart_tor
}

release_date() {
	# outputs something like 20111013
	sed -n -e '1s/^.* - \([0-9]\+\)$/\1/p;q' "$VERSION_FILE"
}

is_clock_way_off() {
	local release_date_secs="$(date -d "$(release_date)" '+%s')"
	local current_date_secs="$(date '+%s')"

	if [ "$current_date_secs" -lt "$release_date_secs" ]; then
	        log "Clock is before the release date"
	        return 0
	fi
	if [ "$(($release_date_secs + 15552000))" -lt "$current_date_secs" ]; then
	        log "Clock is more than 6 months after the release date"
	        return 0
	fi
	return 1
}

start_notification_helper() {
	export DISPLAY=':0.0'
	export XAUTHORITY="$(echo /var/run/gdm3/auth-for-$LIVE_USERNAME-*/database)"
	exec /bin/su -c /usr/local/bin/tails-htp-notify-user "$LIVE_USERNAME" &
}


### Main

start_notification_helper

# Delegate time setting to other daemons if Tor connections work
if tor_is_working; then
	log "Tor has already opened a circuit"
else
	wait_for_tor_consensus
	# It may be that all authority certificates look "expired" due to
	# a clock far off into the future. In that case let's set the clock
	# to the release date.
	if is_clock_way_off; then
		log "The clock looks very badly off. Setting system time to the release date, restarting Tor and fetching a new consensus..."
		date --set="$(release_date)" > /dev/null
		service tor reload
		wait_for_tor_consensus
	fi
	maybe_set_time_from_tor_consensus
fi

wait_for_working_tor

touch $TORDATE_DONE_FILE

log "Restarting htpdate"
service htpdate restart
log "htpdate service restarted with return code $?"
