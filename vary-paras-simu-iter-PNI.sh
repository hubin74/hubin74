!/bin/bash
set -euo pipefail
# Running simulation by reading the parameters from a parameter file and save to the result files.
# Usage: ./vary-bitrate-simu.sh sizes iteration..
#   key: prefix of output file names
#   sizes: a TSV file where each line is a tuple of bit rate 


R="$(pwd)"
FIVEGIPERF3=~/5gdeploy-scenario/20230817/iperf3.sh

#KEY=$1
SIZES_FILE=$(readlink -f $1)
max_iteration=$2


pushd ~/5gdeploy-scenario
source ~/20231017.env
./generate.sh 20231017 +phones=4 +vehicles=4 \
  --dn-workers=0 --phoenix-upf-workers=2 \
  --bridge=n3,eth,gnb0=$N3_GNB0,upf1=$N3_UPF1,upf4=$N3_UPF4 \
  --bridge=n4,eth,smf=$N4_SMF,upf1=$N4_UPF1,upf4=$N4_UPF4 \
  --place="upf1@$CTRL_UPF1(2-3)" \
  --place="dn_internet@$CTRL_UPF1" \
  --place="upf4@$CTRL_UPF4(2-3)" \
  --place="dn_v*@$CTRL_UPF4" \
  --place="*@$CPUSET_PRIMARY"
./upload.sh ~/compose/20231017 $CTRL_UPF1 $CTRL_UPF4
popd

pushd ~/compose/20231017
./compose.sh up
sleep 30
popd

pushd ~/5gdeploy
for UECT in $(docker ps --format='{{.Names}}' | grep '^ue1'); do
  corepack pnpm -s phoenix-rpc --host=$UECT ue-register --dnn=internet
done
for UECT in $(docker ps --format='{{.Names}}' | grep '^ue4'); do
  corepack pnpm -s phoenix-rpc --host=$UECT ue-register --dnn=vcam --dnn=vctl
done
popd

if [[ ! -r $SIZES_FILE ]] ; then
  echo 'Usage: ./vary-bitrate-simu.sh sizes iteration..'
  exit 2
fi
shift 2

#PARAMS=''
#for PARAM in "$@"; do
#  PARAMS="$PARAMS \"${PARAM//\"/\\\"}\""
#done

#  alias 5giperf3='$FIVEGIPERF3'

cd ~/compose/20231017
while read -r -a SIZES; do
  VCAMDL=${SIZES[0]}
  VCTLUL=${SIZES[1]}
  INETUL=${SIZES[2]}
  INETDL=${SIZES[3]}
  DURATION=${SIZES[4]}
  KEY1=${VCAMDL}-${VCTLUL}-${INETUL}-${INETDL}-${DURATION}
  $FIVEGIPERF3 init
  # $FIVEGIPERF3 add internet "^ue1" 10.1.0.0/16 21000 -t $DURATION -u -b ${INETUL}
  env D5G_DNCPUSET=4-7 $FIVEGIPERF3 add internet "^ue1" 10.1.0.0/16 22000 -t $DURATION -u -b ${INETDL} -R
  # $FIVEGIPERF3 add vcam "^ue4" 10.140.0.0/16 24000 -t $DURATION -u -b ${VCAMDL}
  env D5G_DNCPUSET=4-7 $FIVEGIPERF3 add vctl "^ue4" 10.141.0.0/16 25000 -t $DURATION -u -b ${VCTLUL} -R
for i in $(seq 1 $max_iteration); do
  $FIVEGIPERF3 servers; sleep 5
  $FIVEGIPERF3 clients
  $FIVEGIPERF3 wait > e1.log
  $FIVEGIPERF3 collect
  $FIVEGIPERF3 stop
  set +e
  $FIVEGIPERF3 each iperf3/*.json >> $R/results.txt
  $FIVEGIPERF3 total iperf3/internet_21*.json >> $R/results.txt
  $FIVEGIPERF3 total iperf3/internet_22*.json >> $R/results.txt
  $FIVEGIPERF3 total iperf3/vcam_24*.json >> $R/results.txt
  $FIVEGIPERF3 total iperf3/vctl_25*.json >> $R/results.txt
  set -e
  echo $KEY1-$i >> $R/results.txt
  echo '' >> $R/results.txt
  mv ./iperf3 $R/iperf3-${VCAMDL}-${VCTLUL}-${INETUL}-${INETDL}-${DURATION}-$i
done

done < $SIZES_FILE
