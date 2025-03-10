#!/bin/bash

# Parse the named arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --hosts=*)
      PATH_TO_HOSTS_FILE="${1#*=}"
      ;;
    --cert=*)
      PATH_TO_CA_CRT="${1#*=}"
      ;;
    --rpk=*)
      PATH_TO_RPK_FILE="${1#*=}"
      ;;
    --bucket=*)
      BUCKET_NAME="${1#*=}"
      ;;
    *)
      echo "Invalid argument: $1"
      exit 1
  esac
  shift
done

if [ -z "$PATH_TO_HOSTS_FILE" ] || [ -z "$PATH_TO_CA_CRT" ] || [ -z "$PATH_TO_RPK_FILE" ]; then
  echo ""
  echo "ERROR: invalid input"
  echo ""
  echo "Usage: ./testcluster.sh --hosts=PATH_TO_HOSTS_FILE --cert=PATH_TO_CA_CRT"
  echo "hosts  : the fully qualified path to the hosts file"
  echo "cert   : the fully qualified path to the CA cert used to sign the cluster certs"
  echo "rpk    : the fully qualified path to rpk"
  echo "bucket : name of the bucket"
  exit 1
fi


## assemble the redpanda brokers by chopping up the hosts file
# shellcheck disable=SC2155
export REDPANDA_BROKERS=$(sed -n '/^\[redpanda\]/,/^$/p' "${PATH_TO_HOSTS_FILE}" | \
grep 'private_ip=' | \
cut -d' ' -f1 |  \
sed 's/$/:9092/' | \
tr '\n' ',' | \
sed 's/,$/\n/')

## test that we can check status, create a topic and produce to the topic
echo "checking cluster status"
"${PATH_TO_RPK_FILE}" cluster status --brokers "$REDPANDA_BROKERS" --tls-truststore "$PATH_TO_CA_CRT" -v || exit 1

echo "creating topic"
"${PATH_TO_RPK_FILE}" topic create testtopic \
--brokers "$REDPANDA_BROKERS" \
--tls-truststore "$PATH_TO_CA_CRT" \
-v || exit 1

echo "producing to topic"
echo squirrels | "${PATH_TO_RPK_FILE}" topic produce testtopic --brokers "$REDPANDA_BROKERS" --tls-truststore "$PATH_TO_CA_CRT" -v || exit 1

sleep 30

echo "consuming from topic"
testoutput=$("${PATH_TO_RPK_FILE}" topic consume testtopic --brokers "$REDPANDA_BROKERS" --tls-truststore "$PATH_TO_CA_CRT" -v -o :end)
echo $testoutput | grep squirrels || exit 1

echo "checking that bucket is not empty"
# Check if the bucket is empty
object_count=$(aws s3api list-objects --bucket "${BUCKET_NAME}" --region us-west-2 --output json | jq '.Contents | length')

if [ "$object_count" -gt 0 ]; then
    echo "success"
    exit 0
fi

echo "fail"
exit 1
