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
VPN_STATE="active"

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
    --state)
    VPN_STATE="$2" # active|disabled
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

if [[ "$VPN_STATE" != "active" && "$VPN_STATE" != "disabled" ]]; then
    echo "The paramater --state is required. Please choose \"active\" or \"disabled\""
    exit 1
fi

# Set it active
if [[ "$VPN_STATE" == "active" ]]; then
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

else

    PAYLOAD=$(cat <<-EndOfMessage
<rpc>
    <message-vpn>
        <vpn-name>$VPN_NAME</vpn-name>
        <shutdown></shutdown>
    </message-vpn>
</rpc>
EndOfMessage
)

fi

RESPONSE=$(curl -sS --user $SEMP_USER:$SEMP_PASSWORD -X POST -H 'Content-Type: text/xml' --data "$PAYLOAD" $SEMP_API_PATH)

if [[ $RESPONSE != *"execute-result code=\"ok\""* ]]; then
    echo "Unable to set VPN up"
    echo $PAYLOAD
    echo $RESPONSE
    exit 1
fi

exit 0