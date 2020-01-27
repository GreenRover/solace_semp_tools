#!/bin/bash
# ------------------------------------------------------------------------------
#  (c) Copyright by SBB, 2018 - Alle Rechte vorbehalten
#
#  @author   PEng Team
#
#  @purpose
#  Create a system user at solace broker via sempV1
# -------------------------------------------------------------------------

# Defaults
SEMP_API_PATH="http://localhost:8080/SEMP"
SEMP_USER="admin"
SEMP_PASSWORD="admin"
NEW_ROLE="read-only"

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
    --new-username)
    NEW_USER="$2"
    shift # past argument
    shift # past value
    ;;
    --new-password)
    NEW_PASSWORD="$2"
    shift # past argument
    shift # past value
    ;;
    --new-role)
    NEW_ROLE="$2"
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
case $NEW_ROLE in
    read-only|read-write|admin )
        # Nothing to do, this is valid.
        ;;
    * )
        echo "Invalid new role: $NEW_ROLE, allowed are: [read-only|read-write|admin]"
        exit 1
        ;;
esac

PAYLOAD=$(cat <<-EndOfMessage
<rpc>
    <create>
        <username>
            <name>$NEW_USER</name>
            <password>$NEW_PASSWORD</password>
            <cli></cli>
            <access-level>$NEW_ROLE</access-level>
        </username>
    </create>
</rpc>
EndOfMessage
)

RESPONSE=$(curl -sS --user $SEMP_USER:$SEMP_PASSWORD -X POST -H 'Content-Type: text/xml' --data "$PAYLOAD" $SEMP_API_PATH)

if [[ $RESPONSE == *"already exists"* ]]; then
  exit 0
fi

if [[ $RESPONSE == *"execute-result code=\"ok\""* ]]; then
  exit 0
fi

echo $RESPONSE
exit 1