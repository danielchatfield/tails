#! /bin/sh

# Run only when the interface is not "lo":
if [ $1 = "lo" ]; then
   exit 0
fi

# Run whenever an interface gets "up", not otherwise:
if [ $2 != "up" ]; then
   exit 0
fi

# There's nothing to do if Iceweasel is already running
if pgrep -u "${LIVE_USERNAME}" firefox-bin 1>/dev/null 2>&1; then
   exit 0
fi

# Get LIVE_USERNAME
. /etc/live/config.d/username.conf
export DISPLAY=':0.0'
export XAUTHORITY="`echo /var/run/gdm3/auth-for-${LIVE_USERNAME}-*/database`"
export XDG_DATA_DIRS=/usr/share/gnome:/usr/share/gdm/:/usr/local/share/:/usr/share/
export MONKEYSPHERE_VALIDATION_AGENT_SOCKET='http://127.0.0.1:6136'
exec /bin/su -c iceweasel "${LIVE_USERNAME}" &
