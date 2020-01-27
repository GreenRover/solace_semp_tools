#!/bin/bash
# ------------------------------------------------------------------------------
#  (c) Copyright by SBB, 2018 - Alle Rechte vorbehalten
#
#  @author   PEng Team
#
#  @purpose
#  Create a vpn at solace broker via sempV1
# -------------------------------------------------------------------------

# Defaults
SEMP_API_PATH="http://localhost:8080/SEMP"
SEMP_USER="admin"
SEMP_PASSWORD="admin"
VPN_NAME=""
VPN_MAX_SPOOL=""

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -a|--api-url)
    SEMP_API_PATH="$2"
    shift # past argument
    shift # past value
    ;;
    -u|--semp-user)
    SEMP_USER="$2"
    shift # past argument
    shift # past value
    ;;
    -p|--semp-password)
    SEMP_PASSWORD="$2"
    shift # past argument
    shift # past value
    ;;
    --name)
    VPN_NAME="$2"
    shift # past argument
    shift # past value
    ;;
    --limit)
    VPN_MAX_SPOOL="$2" # in MegaByte
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# Validate parameter
if [[ "$VPN_NAME" == "" ]]; then
    echo "The paramater --name is required. Please specifiy a name for the new vpn"
    exit 1
fi

# Create the vpn
PAYLOAD=$(cat <<-EndOfMessage
<rpc>
    <create>
        <message-vpn>
            <vpn-name>$VPN_NAME</vpn-name>
        </message-vpn>
    </create>
</rpc>
EndOfMessage
)

RESPONSE=$(curl -sS --user $SEMP_USER:$SEMP_PASSWORD -X POST -H 'Content-Type: text/xml' --data "$PAYLOAD" $SEMP_API_PATH)

if [[ $RESPONSE != *"execute-result code=\"ok\""* && $RESPONSE != *"already exists"* ]]; then
    echo "Unable to create VPN"
    echo $PAYLOAD
    echo $RESPONSE
    exit 1
fi

# Set it active
PAYLOAD=$(cat <<-EndOfMessage
<rpc>
    <message-vpn>
        <vpn-name>$VPN_NAME</vpn-name>
        <no>
            <shutdown></shutdown>
        </no>
    </message-vpn>
</rpc>
EndOfMessage
)

RESPONSE=$(curl -sS --user $SEMP_USER:$SEMP_PASSWORD -X POST -H 'Content-Type: text/xml' --data "$PAYLOAD" $SEMP_API_PATH)

if [[ $RESPONSE != *"execute-result code=\"ok\""* ]]; then
    echo "Unable to set VPN up"
    echo $PAYLOAD
    echo $RESPONSE
    exit 1
fi


# Set spool limit
PAYLOAD=$(cat <<-EndOfMessage
    <rpc>
        <message-spool>
            <vpn-name>$VPN_NAME</vpn-name>
            <max-spool-usage>
                <size>$VPN_MAX_SPOOL</size>
            </max-spool-usage>
        </message-spool>
    </rpc>
EndOfMessage
)

if [[ "$VPN_MAX_SPOOL" != "" ]]; then
    RESPONSE=$(curl -sS --user $SEMP_USER:$SEMP_PASSWORD -X POST -H 'Content-Type: text/xml' --data "$PAYLOAD" $SEMP_API_PATH)

    if [[ $RESPONSE != *"execute-result code=\"ok\""* ]]; then
        echo "Unable to set VPN max spool"
        echo $PAYLOAD
        echo $RESPONSE
        exit 1
    fi
fi

exit 0