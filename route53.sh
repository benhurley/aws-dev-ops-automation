#!/bin/sh
#route53.sh

# This script handles switching over live traffic to free up resources within a region.

# Assumptions:
# 1. Since setting every record set weight to '0' will evenly distribute traffic, '0' will only be used for
#    0% traffic situations to avoid confusion. Traffic will be split mathematically when needed (explained below).
# 2. We are only supporting weighted routing policy so far, as this script reads current weighted values
#    and pushes desired changes back into Route 53

# Possible combinations for incoming weight parameters

# 1. East=5, West=0     // 100% traffic to east                 ((5 / 5+0) = 1 * 100 = 100% east)
# 2. East=0, West=5     // 100% traffic to west                 ((5 / 5+0) = 1 * 100 = 100% west)
# 3. East=9, West=1     // 90% traffic to east, 10% to west     ((9 / 9+1) = 0.9 * 100 = 90% east, (1 / 9+1) = 0.1 * 100 = 10% west)
# 4. East=1, West=9     // 10% traffic to east, 90% to west     ((1 / 9+1) = 0.1 * 100 = 10% east, (9 / 9+1) = 0.9 * 100 = 90% west)
# 5. East=5, West=5     // 50% traffic to each region           ((5 / 5+5) = 0.5 * 100 = 50% east, (5 / 5+5) = 0.5 * 100 = 50% west)

echo
echo ---------------------------------
echo Initiating Route53 Traffic Change
echo ---------------------------------
echo

# Initialize incoming variables
hostedZoneID=$1
recordName=$2
newEastWeight=$3
newWestWeight=$4

echo Hosted Zone ID: $hostedZoneID
echo Record Name: $recordName
echo

# Pull down current configs from Route 53 for given record set name
# recordSets="$(aws route53 list-resource-record-sets --hosted-zone-id $hostedZoneID --query "ResourceRecordSets[?Name == 'recordName']")"

# Example for Testing
recordSets='[
    {
        "Name": "this-that.com",
        "Type": "CNAME",
        "Value": "us-east-1-this-that.com",
        "TTL": 60,
        "Weight": 5,
        "SetID": "API gateway us-east-1"
    },
    {
        "Name": "this-that.com",
        "Type": "CNAME",
        "Value": "us-west-2-this-that.com",
        "TTL": 60,
        "Weight": 0,
        "SetID": "API gateway us-west-2"
    }
]'

#echo Full record set:
#echo $recordSets
#echo

numRecords="$(echo "$recordSets" | jq 'length')"

if [[ $numRecords = 2 ]];
then
    record1="$(echo "$recordSets" | jq '.[0]')"
    #echo record1: $record1
    #echo

    record2="$(echo "$recordSets" | jq '.[1]')"
    #echo record2: $record2
    #echo

else
    echo Did not find two records for $recordName
    exit
fi

# Break out each region
if [[ $record1 = *east* ]] ;
then
    if [[ $record2 = *west* ]] ;
    then
        eastRecord=$record1
        westRecord=$record2
    else
        echo Could not find valid record set for west region.
        exit
    fi
elif [[ $record2 = *east* ]]  ;
then
    if [[ $record1 = *west* ]] ;
    then
        eastRecord=$record2
        westRecord=$record1
    else
        echo Could not find valid record set for west region.
        exit
    fi
else
    echo Could not find valid record set for east region
    exit
fi    

echo Record Set for East Region:
echo $eastRecord

echo
echo Record Set for West Region:
echo $westRecord

echo
echo Current Route53 weights for each region in $recordName:
eastWeight="$(echo "$eastRecord" | jq '.Weight')"
westWeight="$(echo "$westRecord" | jq '.Weight')"
echo East Weight: $eastWeight
echo West Weight: $westWeight

echo
echo Current traffic distribution between each region in $recordName:

# calculate current traffic percentages
totalWeight="$(expr $eastWeight + $westWeight)"
eastPercent="$(expr $(expr $eastWeight / $totalWeight) \* 100)"
westPercent="$(expr $(expr $westWeight / $totalWeight) \* 100)"

echo East: $eastPercent%
echo West: $westPercent%
echo

#calculate new traffic percentages
newTotalWeight="$(expr $newEastWeight + $newWestWeight)"
newEastPercent=$((200*$newEastWeight/$newTotalWeight % 2 + 100*$newEastWeight/$newTotalWeight))
newWestPercent=$((200*$newWestWeight/$newTotalWeight % 2 + 100*$newWestWeight/$newTotalWeight))

echo New traffic distribution between each region in $recordName:
echo East: $newEastPercent%
echo West: $newWestPercent%
echo

echo New weights to push to Route 53 for $recordName
echo New East Weight: $newEastWeight
echo New West Weight: $newWestWeight

# Pushing updates to Route 53 record sets
# TODO

echo
echo ---------------------------
echo End Route53 Traffic Change
echo ---------------------------
echo


