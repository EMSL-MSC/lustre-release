#!/bin/sh

export PATH=`dirname $0`/../utils:$PATH

LCONF=${LCONF:-lconf}
NAME=${NAME:-local}
LLMOUNT=${LLMOUNT:-llmount}

config=$NAME.xml
mkconfig=$NAME.sh

if [ "$PORTALS" ]; then
  portals_opt="--portals=$PORTALS"
fi

if [ "$LUSTRE" ]; then
  lustre_opt="--lustre=$LUSTRE"
fi

if [ "$LDAPURL" ]; then
    conf_opt="--ldapurl $LDAPURL --config $NAME"
else
    if [ ! -f $config -o $mkconfig -nt $config ]; then
	sh $mkconfig $config || exit 1
    fi
    conf_opt="$config"
fi    

[ "$NODE" ] && node_opt="--node $NODE"

${LCONF} $NOMOD $portals_opt $lustre_opt $node_opt $@ $conf_opt || exit 2

[ $DEBUG ] && sysctl -w portals.debug=$DEBUG

if [ "$MOUNT2" ]; then
	$LLMOUNT -v `hostname`:/mds1/client $MOUNT2 || exit 3
fi
