#!/bin/sh
# Copyright 2014 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# headless usage:
# gcutil addinstance [instance_name] --metadata=startup-script-url:http://storage.googleapis.com/gce-scripts/gee.sh
#
# To check what sort of information will be logged have a look at the sample logfile:
# http://storage.googleapis.com/gce-scripts/gee_sample_log.txt
# WARNING! this tool by default exposing potentially sensitive data to Google Support
# use the --skip flag to supress some sections of the output or change logging $OUTPUT
#
# Alternatively if network connection to cloud storage is still working the output 
# can be directed to a file and that copied across after running the tool, 
# which file than can be trimmed by the customer before sending it to the support team.
#
# the flags are not handled with getops to remain POSIX and portable
OUTPUT=default
FORCE=0
VERBOSE=1
while test $# -gt 0 ; do

  # switches
  if test "$1" = "-h" ; then
     echo "Usage: "
     echo "-h This help"
     echo "-f force to run without UID 0 (root)"
     echo "-v verbose output of each command"
     echo "--out=/tmp/logfile full path of the output file,"
     echo "      /dev/kmesg console if unspecified."
     echo "--skip=[network,metadata,authkeys,sshdconf,sshd,sys,usersec,traceroute]"
     echo "      comma separated list of tests to skip."
     exit
  fi;
  if test "$1" = "-f" ; then FORCE=1 ; shift ; continue; fi;
  if test "$1" = "-v" ; then VERBOSE=1 ; shift ; continue; fi;

  # options with arguments
  case "$1" in
  --out=*) OUTPUT="${1##--out=}" ; shift; continue; break ;;
  --skip=*) SKIP="${1##--skip=}" ; shift; continue; break ;;
  esac

  # unknown argument: error
  echo "Unknown option $1"
  exit 1
done

if [ $(/usr/bin/id -u) -ne 0 ] && [ "$FORCE" != "1" ]; then
  echo -n "This script is designed to run as user id 0 (root). Current UID: "
  /usr/bin/id -u
  echo "Try sudo $0 or run it after sudo su -"
  echo "Alternatively rerun with -f flag to ignore this check."
  echo "Some tests will fail due to lack of permission!"
  exit
fi;

if [ "$OUTPUT" = "default" ]; then
  exec >/dev/kmsg 2>&1
else
  exec >$OUTPUT 2>&1
fi;

# create some number sequence eg. 83759.3183643.58122, works with or without urandom
RAND=`echo $(cat /proc/uptime)$(od -A n -t d -N 1 /dev/urandom) | sed 's/[[:blank:]]//g'`
TMP=${HOME}/tmp-gee-${RAND}
mkdir -p $TMP
if [ $? = 0 ]; then
  chmod 0700 $TMP
  mkdir -p ${TMP}/ssh
  chmod 0700 $TMP/ssh
  DOTSSH=${TMP}/ssh
else
  echo "creating TMP failed"
  exit 1 
fi;

if [ -f /bin/traceroute ]; then
  TRACEROUTE=/bin/traceroute
elif [ -f /usr/sbin/traceroute ]; then
  TRACEROUTE=/usr/sbin/traceroute
else
  echo "no traceroute in /usr/sbin or /bin relying on PATH"
  TRACEROUTE=traceroute
fi;
if [ "$VERBOSE" = "1" ]; then
   PS4='$LINENO :'
   set -x;
fi;

echo '####### GEE #########'
echo $SKIP | grep -qw "network"
if [ $? = 1 ]; then
  echo '### Network'
  /sbin/ifconfig
  cat /etc/resolv.conf
  /sbin/iptables-save | egrep -v 'Generated|Completed'
  /bin/netstat -rn
  cat /etc/hosts.deny  | grep -v ^#
  echo
fi;
echo '### SSH and meta server reach'
md5sum /usr/bin/ssh
cat << EOF | /usr/bin/env python
import socket

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
result = s.connect_ex(('127.0.0.1', 22))

if(result == 0):
    print 'tcp port 22 connected:',
    print(s.recv(4096)),
    s.close()
else:
    print 'could not connect to port 22'
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
result = s.connect_ex(('169.254.169.254', 80))
if(result == 0):
    print 'metaserver 169.254.169.254:80 connected'
    s.close()
else:
    print 'metaserver 169.254.169.254:80 connection failed'
EOF
# netstat -n no name resolution -t tpc -p pids
/bin/netstat -lntpA inet | egrep 'sshd|:22|PID'
# this is without -n to check name lookup as well should complete in 1 hop
${TRACEROUTE} apis.google.com&
echo
echo $SKIP | grep -qw "metadata"
if [ $? = 1 ]; then
  echo '### Authorized meta'
  META1=${TMP}/authkeys1
  META2=${TMP}/authkeys2
  /usr/bin/curl -Sso ${META1} http://metadata.google.internal/0.1/meta-data/authorized-keys
  cat ${META1}
  /usr/share/google/get_metadata_value authorized_keys >${META2}
  /usr/bin/diff -su ${META1} ${META2}
  rm -f ${META1} ${META2}
fi;
echo $SKIP | grep -qw "authkeys"
if [ $? = 1 ]; then
  echo '### Authorized keys'
  l=$(grep "^UID_MIN" /etc/login.defs)
  l1=$(grep "^UID_MAX" /etc/login.defs)
  HOMEDIRS=$(awk -F':' -v "min=${l##UID_MIN}" -v "max=${l1##UID_MAX}" '{ if ( $3 >= min && $3 <= max ) print $0}' /etc/passwd | cut -d ':' -f 6)
  echo "$HOMEDIRS" | while read homedir; do
    ssh-keygen -lf $homedir/.ssh/authorized_keys;
    if [ -f $homedir/.ssh/authorized_keys2 ]; then
      ssh-keygen -lf $homedir/.ssh/authorized_keys2;
    fi;
  done;
fi;
echo $SKIP | grep -qw "sshdconf"
if [ $? = 1 ]; then
  echo '/etc/ssh/sshd_config'
  # open a secondary ssh daeomon in debug mode for 5 minutes on port 3562
  # this exits either after 5 minutes or on first connection
  egrep -v '^#|^$' /etc/ssh/sshd_config | grep -v Port | grep -v PermitRootLogin | grep -v PasswordAuthentication  >${DOTSSH}/sshd_config
cat << EOF >> ${DOTSSH}/sshd_config
Port 3562
PasswordAuthentication no
PermitRootLogin no
Match User root Address 127.0.0.1
    PermitRootLogin forced-commands-only
    ForceCommand /bin/echo
EOF
  SSHD_OPTIONS="-d -f ${DOTSSH}/sshd_config -o 'AuthorizedKeysFile ${DOTSSH}/authorized_keys'"
  echo $SSHD_OPTIONS | xargs timeout 5m /usr/sbin/sshd 2>&1 | grep -v 'debug1: rexec_argv' && rm -f ${DOTSSH}/sshd_config &
fi;
echo $SKIP | grep -qw "sshd"
if [ $? = 1 ]; then
  ls -ldZ $HOME/.ssh
  ls -lZ $HOME/.ssh
  KEY=${DOTSSH}/test-key
  echo -e '\n\n' | ssh-keygen -q -f ${KEY} -N '' -t dsa -V +2m
  echo -n 'from="127.0.0.1",command="/bin/echo" ' > ${DOTSSH}/authorized_keys
  cat ${KEY}.pub >> ${DOTSSH}/authorized_keys
  chmod 0600 ${DOTSSH}/authorized_keys
  ssh -v -p 3562 -i ${KEY} -o StrictHostKeyChecking=no localhost echo "2>&1" && echo ">>> SSH localhost login succcess" || echo ">>> SSH on localhost failed"
  rm -f ${KEY} ${KEY}.pub
  rm -f ${DOTSSH}/authorized_keys
  echo
fi;
echo $SKIP | grep -qw "sys"
if [ $? = 1 ]; then
  echo '### System, filesystem, memory'
  # OS version info
  if [ -f /usr/bin/lsb_release ]; then
    /usr/bin/lsb_release -a
  else
    find /etc -name "*release" -type f -exec cat {} \;
  fi;
  /bin/uname -a
  /bin/mount
  cat /etc/fstab
  /bin/mount -fav
  echo
  /bin/df -l -x tmpfs -P
  ls /
  free -k
  # load averages
  /usr/bin/uptime
  echo
fi;
echo $SKIP | grep -qw "usersec"
if [ $? = 1 ]; then
  echo '### Users and security'
  cat /etc/passwd
  md5sum /usr/share/google/google_daemon/manage_accounts.py
  ps -C manage_accounts.py -C startpar uw
  /usr/sbin/visudo -c
  cat /etc/sudoers | egrep -v '^#|^$'
  cat /etc/selinux/semanage.conf | egrep -v '^#|^$'
  if [ -f /usr/bin/faillog ]; then
    /usr/bin/faillog -a -u ${l##UID_MIN}-$(echo ${l1##UID_MAX}) | grep -v '^$'
  fi;
fi;
# this should be in the network section however since it takes a while
# it is started in the background, the output however gets scattered otherwise
# ie. if it is an earlier command
echo $SKIP | grep -qw "traceroute"
if [ $? = 1 ]; then
  ${TRACEROUTE} -n au.pool.ntp.org
  echo
fi;
rm -rf ${TMP}
echo "### == DONE =="
