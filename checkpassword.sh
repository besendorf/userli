#!/bin/bash

# Example Dovecot checkpassword script that may be used as both passdb or userdb.
#
# Originally written by Nikolay Vizovitin, 2013.

# Assumes authentication DB is in /etc/dovecot/users, each line has '<user>:<password>' format.
# Place this script into /etc/dovecot/checkpassword.sh file and make executable.
# Implementation guidelines at http://wiki2.dovecot.org/AuthDatabase/CheckPassword

# The first and only argument is path to checkpassword-reply binary.
# It should be executed at the end if authentication succeeds.
CHECKPASSWORD_REPLY_BINARY="$1"

# Messages to stderr will end up in mail log (prefixed with "dovecot: auth: Error:")
LOG=/vagrant/checkpassword.log

# User and password will be supplied on file descriptor 3.
INPUT_FD=3

# Error return codes.
ERR_PERMFAIL=1
ERR_NOUSER=3
ERR_TEMPFAIL=111

# Make testing this script easy. To check it just run:
#   printf '%s\0%s\0' <user> <password> | ./checkpassword.sh test; echo "$?"
if [ "$CHECKPASSWORD_REPLY_BINARY" = "test" ]; then
	CHECKPASSWORD_REPLY_BINARY=/bin/true
	INPUT_FD=0
fi

# Just a simple logging helper.
log_result()
{
	echo "$*; Input: $USER:$PASS; Home: $HOME; Reply binary: $CHECKPASSWORD_REPLY_BINARY" >>$LOG
}

# Read input data. It is available from $INPUT_FD as "${USER}\0${PASS}\0".
# Password may be empty if not available (i.e. if doing credentials lookup).
read -d $'\0' -r -u $INPUT_FD USER
read -d $'\0' -r -u $INPUT_FD PASS

# Both mailbox and domain directories should be in lowercase on file system.
# So let's convert login user name to lowercase and tell Dovecot that 'user' and 'home' 
# (which overrides 'mail_home' global parameter) values should be updated.
# Of course, conversion to lowercase may be done in Dovecot configuration as well.
export USER="`echo \"$USER\" | tr 'A-Z' 'a-z'`"
mail_name="`echo \"$USER\" | awk -F '@' '{ print $1 }'`"
domain_name="`echo \"$USER\" | awk -F '@' '{ print $2 }'`"
export HOME="/var/vmail/$domain_name/$mail_name/"

# CREDENTIALS_LOOKUP=1 environment is set when doing non-plaintext authentication.
#if [ "$CREDENTIALS_LOOKUP" = 1 ]; then
if [ "$AUTHORIZED" = 1 ]; then
    lookup_result=$(/vagrant/bin/console usrmgmt:users:check $USER)
else
    lookup_result=$(/vagrant/bin/console usrmgmt:users:check $USER $PASS)
fi

if [ "$?" -eq 0 ]; then
	# Dovecot calls the script with AUTHORIZED=1 environment set when performing a userdb lookup.
	# The script must acknowledge this by changing the environment to AUTHORIZED=2,
	# otherwise the lookup fails.
	[ "$AUTHORIZED" != 1 ] || export AUTHORIZED=2

	# And here's how to return extra fields from userdb/passdb lookup, e.g. 'uid' and 'gid'.
	# All virtual mail users in Plesk actually run under 'popuser'.
	# See also:
	#   http://wiki2.dovecot.org/PasswordDatabase/ExtraFields
	#   http://wiki2.dovecot.org/UserDatabase/ExtraFields
	#   http://wiki2.dovecot.org/VirtualUsers
	export userdb_uid=5000
	export userdb_gid=5000
	export EXTRA="userdb_uid userdb_gid $EXTRA"

	if [ "$CREDENTIALS_LOOKUP" = 1 ]; then
		echo CREDENTIALS_LOOKUP >>$LOG
		# If this is a credentials lookup, return password together with its scheme.
		# The password scheme that Dovecot wants is available in SCHEME environment variable
		# (e.g. SCHEME=CRAM-MD5), however 'PLAIN' scheme can be converted to anything internally
		# by Dovecot, so we'll just return 'PLAIN' password.
		found_password="`echo \"$lookup_result\" | awk -F ':' '{ print $2 }'`"
		export password="{PLAIN}$found_password"
		export EXTRA="password $EXTRA"
		log_result "credentials lookup result: '$password' [SCHEME='$SCHEME', EXTRA='$EXTRA']"
	else
		log_result "lookup result: '$lookup_result'"
	fi

	# At the end of successful authentication execute checkpassword-reply binary.
	exec $CHECKPASSWORD_REPLY_BINARY
else
	# If matching credentials were not found, return proper error code depending on lookup mode.
	if [ "$AUTHORIZED" = 1 -a "$CREDENTIALS_LOOKUP" = 1 ]; then
		log_result "lookup failed (user not found)"
		exit $ERR_NOUSER
	else
		log_result "lookup failed (credentials are invalid)"
		exit $ERR_PERMFAIL
	fi
fi

# vim:set ts=4 sts=4 sw=4 ai:

