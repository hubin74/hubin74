#!/bin/bash
# Running simulation by reading the parameters from a parameter file and save to the result files.
# Usage: ./vary-bitrate-simu.sh key sizes..
#   key: prefix of output file names
#   sizes: a TSV file where each line is a tuple of bit rate


#R="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/.. && pwd )"
R="$(pwd)"

#KEY=$1
SIZES_FILE=$1

#BFSIZE_REPORT_TAG=${BFSIZE_REPORT_TAG:-bfsize}

if [[ ! -r $SIZES_FILE ]] ; then
  echo 'Usage: ./vary-bitrate-simu.sh sizes..'
  exit 2
fi
shift 2

#PARAMS=''
#for PARAM in "$@"; do
#  PARAMS="$PARAMS \"${PARAM//\"/\\\"}\""
#done

#  alias 5giperf3='~/5gdeploy-scenario/20230817/iperf3.sh'
#  5giperf3 init

max_iteration=2

while read -r -a SIZES; do
  BF1SIZE=${SIZES[0]}
  BF2SIZE=${SIZES[1]}
  BF3SIZE=${SIZES[2]}
  BF4SIZE=${SIZES[3]}
  BF5SIZE=${SIZES[4]}
  KEY1=${BF1SIZE}-${BF2SIZE}-${BF3SIZE}-${BF4SIZE}-${BF5SIZE}
  ~/5gdeploy-scenario/20230817/iperf3.sh add vcam "^ue4" 10.140.0.0/16 24000 -t $BF5SIZE -u -b ${BF1SIZE}
  ~/5gdeploy-scenario/20230817/iperf3.sh add vctl "^ue4" 10.141.0.0/16 25000 -t $BF5SIZE -u -b ${BF2SIZE} -R
  ~/5gdeploy-scenario/20230817/iperf3.sh add internet "^ue1" 10.1.0.0/16 21000 -t $BF5SIZE -u -b ${BF3SIZE}
  ~/5gdeploy-scenario/20230817/iperf3.sh add internet "^ue1" 10.1.0.0/16 22000 -t $BF5SIZE -u -b ${BF4SIZE} -R
  ~/5gdeploy-scenario/20230817/iperf3.sh servers; sleep 5
  ~/5gdeploy-scenario/20230817/iperf3.sh clients
for i in $(seq 1 $max_iteration); do
  ~/5gdeploy-scenario/20230817/iperf3.sh wait > e1.log
#  ~/5gdeploy-scenario/20230817/iperf3.sh collect
#  ~/5gdeploy-scenario/20230817/iperf3.sh stop
  while read -r -a SIZES; do
    result=${SIZES[0]}
    if [[ $result -eq 1 ]]
    then
      echo "error"
      break
    else
      echo "successful"
      sleep 1
    fi
  done < e1.log

  if [[ $result -eq 0 ]]
  then
    echo "successful2"
    break
  else
    echo "error2"
    sleep 1
  fi
done

  ~/5gdeploy-scenario/20230817/iperf3.sh collect
  ~/5gdeploy-scenario/20230817/iperf3.sh stop
  ~/5gdeploy-scenario/20230817/iperf3.sh each iperf3/*.json >> results.txt
  ~/5gdeploy-scenario/20230817/iperf3.sh total iperf3/internet_21*.json >> results.txt
  ~/5gdeploy-scenario/20230817/iperf3.sh total iperf3/internet_22*.json >> results.txt
  ~/5gdeploy-scenario/20230817/iperf3.sh total iperf3/vcam_24*.json >> results.txt
  ~/5gdeploy-scenario/20230817/iperf3.sh total iperf3/vctl_25*.json >> results.txt
  echo $KEY1 >> results.txt
  echo '' >> results.txt
  cp -R $R/iperf3 $R/iperf3-${BF1SIZE}-${BF2SIZE}-${BF3SIZE}-${BF4SIZE}-${BF5SIZE}
done < $SIZES_FILE
