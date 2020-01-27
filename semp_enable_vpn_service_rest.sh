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
PORT=""

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
    --vpn)
    VPN_NAME="$2"
    shift # past argument
    shift # past value
    ;;
    --port)
    PORT="$2"
    shift # past argument
    shift # past value
    ;;
    --service)
    SERVICE="$2"
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
    echo "The paramater --name is required. Please specifiy the name of the vpn"
    exit 1
fi

if [[ "$PORT" == "" && ! $PORT =~ ^-?[0-9]+$ ]]; then
    echo "The paramater --port is required and have to be an integer. Please specifiy a port for the service"
    exit 1
fi

case $SERVICE in
    http )
        SERVICE_NAME="plain-text"
        FLAGS=""
        ;;
    https )
        SERVICE_NAME="ssl"
        FLAGS="<ssl></ssl>"
        ;;
    * )
        echo "Invalid service: $SERVICE, allowed are: [http|https]"
        exit 1
        ;;
esac

# Shutdown service
PAYLOAD=$(cat <<-EndOfMessage
<rpc semp-version="soltr/9_3VMR">
    <message-vpn>
        <vpn-name>$VPN_NAME</vpn-name>
        <service>
            <rest>
                <incoming>
                    <$SERVICE_NAME>
                        <shutdown></shutdown>
                    </$SERVICE_NAME>
                </incoming>
            </rest>
        </service>
    </message-vpn>
</rpc>
EndOfMessage
)

RESPONSE=$(curl -sS --user $SEMP_USER:$SEMP_PASSWORD -X POST -H 'Content-Type: text/xml' --data "$PAYLOAD" $SEMP_API_PATH)

if [[ $RESPONSE != *"execute-result code=\"ok\""* ]]; then
    echo "Unable to shutdown service"
    echo $PAYLOAD
    echo $RESPONSE
    exit 1
fi

# Set port
PAYLOAD=$(cat <<-EndOfMessage
<rpc semp-version="soltr/9_3VMR">
    <message-vpn>
        <vpn-name>$VPN_NAME</vpn-name>
        <service>
            <rest>
                <incoming>
                    <listen-port>
                        <port>$PORT</port>
                        $FLAGS
                    </listen-port>
                </incoming>
            </rest>
        </service>
    </message-vpn>
</rpc>
EndOfMessage
)

RESPONSE=$(curl -sS --user $SEMP_USER:$SEMP_PASSWORD -X POST -H 'Content-Type: text/xml' --data "$PAYLOAD" $SEMP_API_PATH)

if [[ $RESPONSE != *"execute-result code=\"ok\""* ]]; then
    echo "Unable to set port"
    echo $PAYLOAD
    echo $RESPONSE
    exit 1
fi

# Set messaging mode
PAYLOAD=$(cat <<-EndOfMessage
<rpc semp-version="soltr/9_3VMR">
    <message-vpn>
        <vpn-name>$VPN_NAME</vpn-name>
        <service>
            <rest>
                <mode>
                    <messaging></messaging>
                </mode>
            </rest>
        </service>
    </message-vpn>
</rpc>
EndOfMessage
)

RESPONSE=$(curl -sS --user $SEMP_USER:$SEMP_PASSWORD -X POST -H 'Content-Type: text/xml' --data "$PAYLOAD" $SEMP_API_PATH)

if [[ $RESPONSE != *"execute-result code=\"ok\""* ]]; then
    echo "Unable to set messaging mode"
    echo $PAYLOAD
    echo $RESPONSE
    exit 1
fi


# Enable service
PAYLOAD=$(cat <<-EndOfMessage
<rpc semp-version="soltr/9_3VMR">
    <message-vpn>
        <vpn-name>$VPN_NAME</vpn-name>
        <service>
            <rest>
                <incoming>
                    <$SERVICE_NAME>
                        <no>
                            <shutdown></shutdown>
                        </no>
                    </$SERVICE_NAME>
                </incoming>
            </rest>
        </service>
    </message-vpn>
</rpc>
EndOfMessage
)

RESPONSE=$(curl -sS --user $SEMP_USER:$SEMP_PASSWORD -X POST -H 'Content-Type: text/xml' --data "$PAYLOAD" $SEMP_API_PATH)

if [[ $RESPONSE != *"execute-result code=\"ok\""* ]]; then
    echo "Unable to enable service"
    echo $PAYLOAD
    echo $RESPONSE
    exit 1
fi

exit 0