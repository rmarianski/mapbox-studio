#!/usr/bin/env bash
set -e

PLATFORM=$(uname -s | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/")
COMMIT_MESSAGE=$(git show -s --format=%B $TRAVIS_COMMIT | tr -d '\n')
GITSHA="$1"

if [ $PLATFORM != "linux" ]; then
    exit 0
fi

if test "${COMMIT_MESSAGE#*'[windebug]'}" == "$COMMIT_MESSAGE"
then
    echo "no [windebug] in commit message, nothing to do here."
    exit 0
fi

echo "[windebug] in commit message, about to start server"

sleep=10
date_time=`date +%Y%m%d%H%M`
start_timestamp=`date +"%s"`
maxtimeout=2880
region="eu-central-1"
ami_id="ami-3690a22b"

user_data="<powershell>
    ([ADSI]\"WinNT://./Administrator\").SetPassword(\"${CRED}\")
    & \"C:\\Program Files (x86)\\Git\\bin\\git\" clone https://github.com/mapbox/windows-builds.git Z:\\mbs
    & Invoke-WebRequest https://mapbox.s3.amazonaws.com/node-cpp11/v0.10.33/x64/node.exe -OutFile Z:\\mbs\\node.exe
    & cd /d Z:\\mbs
    & npm install
    </powershell>
    <persist>true</persist>"

id=$(aws ec2 run-instances \
    --instance-initiated-shutdown-behavior terminate \
    --region $region \
    --image-id $ami_id \
    --count 1 \
    --instance-type c3.4xlarge \
    --user-data "$user_data" | jq -r '.Instances[0].InstanceId')

echo "Created instance: $id"

aws ec2 create-tags --region $region --resources $id --tags "Key=Name,Value=Temp-mapbox-studio-windebug-server-${TRAVIS_REPO_SLUG}-${TRAVIS_JOB_NUMBER}"
aws ec2 create-tags --region $region --resources $id --tags "Key=GitSha,Value=$gitsha"

dns=''
instance_status_stopped=$(aws ec2 describe-instances --region $region --instance-id $id | jq -r '.Reservations[0].Instances[0].State.Name')
until [ "$instance_status_stopped" = "stopped" ]; do
    if [ `expr $(date "+%s") - $start_timestamp` -gt $maxtimeout ]; then
        echo "The instance has timed out. Terminating instance: $id"
        terminating_status=$(aws ec2 terminate-instances --region $region --instance-ids $id | jq -r '.TerminatingInstances[0].CurrentState.Name')
        exit 1
    fi

    instance_status_stopped=$(aws ec2 describe-instances --region $region --instance-id $id | jq -r '.Reservations[0].Instances[0].State.Name')
    echo "Instance stopping status eu-central-1 $id: $instance_status_stopped"

    if [[ -z $dns ]]; then
        dns=$(aws ec2 describe-instances --instance-ids $id --region $region --query "Reservations[0].Instances[0].PublicDnsName")
        dns="${dns//\"/}"
        echo "temporary mapbox-studio Windows Debug Server: $dns"
    fi;
    if [[ ${#dns} -gt 1 ]]; then
        instance_status_stopped="stopped"
    fi;

    sleep $sleep
done


exit 0
