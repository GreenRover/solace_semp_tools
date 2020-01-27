#!/bin/bash
# ------------------------------------------------------------------------------
#  (c) Copyright by SBB, 2018 - Alle Rechte vorbehalten
#
#  @author   PEng Team
#
#  @purpose
#  Set the hardware spool limit of solace broker via sempV1
#  hardware spool limit == the maximum disk space that the whole broker is allowed to consume
# -------------------------------------------------------------------------

# Defaults
SEMP_API_PATH="http://localhost:8080/SEMP"
SEMP_USER="admin"
SEMP_PASSWORD="admin"

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
    -l|--limit)
    LIMIT="$2" # in MegaByte
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

if [[ "$LIMIT" == "" ]]; then
    echo "The paramater --limit is required. Please specifiy a int between 0 and 6`000`000"
    exit 1
fi

PAYLOAD=$(cat <<-EndOfMessage
<rpc>
    <hardware>
        <message-spool>
            <max-spool-usage>
                <size>$LIMIT</size>
            </max-spool-usage>
        </message-spool>
    </hardware>
</rpc>
EndOfMessage
)

RESPONSE=$(curl -sS --user $SEMP_USER:$SEMP_PASSWORD -X POST -H 'Content-Type: text/xml' --data "$PAYLOAD" $SEMP_API_PATH)
if [[ $RESPONSE == *"execute-result code=\"ok\""* ]]; then
  exit 0
fi

echo $RESPONSE
exit 1
