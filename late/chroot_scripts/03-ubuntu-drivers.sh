#!/bin/sh

. /usr/share/dell/scripts/fifuncs ""

IFHALT "Run ubuntu-drivers autoinstall"
echo 'APT::Get::AllowUnauthenticated "true";' > /etc/apt/apt.conf.d/99disable_authentication
for i in `ubuntu-drivers list`; do
    if ! dpkg-query -W $i >/dev/null 2>&1; then
        apt-get install --yes $i
    fi
done

#install meta package based upon BIOS ID
BIOS_ID=$(dmidecode -t 11 | sed '/String 2:/!d; s,.*String 2: 1\[,,; s,\],,' | tr A-Z a-z)
SERIES=$(lsb_release -cs)
for pkg in dell-$BIOS_ID-meta dell-$BIOS_ID-$SERIES-meta; do
    if ! dpkg-query -W $pkg >/dev/null 2>&1; then
        apt-get install --yes $pkg || true
    fi
done

rm /etc/apt/apt.conf.d/99disable_authentication
IFHALT "Done with ubuntu-drivers autoinstall"
