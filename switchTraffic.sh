#!/bin/sh
#switchTraffic.sh

# This script handles switching over live traffic between regions (us-east-1 and us-west-2)

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
echo ---------------------------
echo Initiating Traffic Switcher
echo ---------------------------
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
recordSets="$(aws route53 list-resource-record-sets --hosted-zone-id $hostedZoneID --query "ResourceRecordSets[?Name == '$recordName']")"

numRecords="$(echo "$recordSets" | jq 'length')"

if [[ $numRecords = 2 ]];
then
    record1="$(echo "$recordSets" | jq '.[0]')"
    record2="$(echo "$recordSets" | jq '.[1]')"
else
    echo Did not find two records for $recordName
    exit 1
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
        exit 1
    fi
elif [[ $record2 = *east* ]]  ;
then
    if [[ $record1 = *west* ]] ;
    then
        eastRecord=$record2
        westRecord=$record1
    else
        echo Could not find valid record set for west region.
        exit 1
    fi
else
    echo Could not find valid record set for east region
    exit 1
fi    

echo Record Set for East Region:
echo $eastRecord

echo
echo Record Set for West Region:
echo $westRecord

# Pull name

nameString="$(echo "$eastRecord" | jq '.Name')"

# Pull Set ID for each region
echo
echo Current Set IDs for each region in $recordName:
setIDEast="$(echo "$eastRecord" | jq '.SetIdentifier')"
setIDWest="$(echo "$westRecord" | jq '.SetIdentifier')"
echo East SetID: $setIDEast
echo West SetID: $setIDWest

# Pull Type for each region
echo
echo Current Type for each region in $recordName:
typeEast="$(echo "$eastRecord" | jq '.Type')"
typeWest="$(echo "$westRecord" | jq '.Type')"
echo East Type: $typeEast
echo West Type: $typeWest

# Pull TTL for each region
echo
echo Current TTL for each region in $recordName:
ttlEast="$(echo "$eastRecord" | jq '.TTL')"
ttlWest="$(echo "$westRecord" | jq '.TTL')"
echo East TTL: $ttlEast
echo West TTL: $ttlWest

# Pull Resource Values for each region
echo
echo Current Resource Values for each region in $recordName:
resourceValEast="$(echo "$eastRecord" | jq '.ResourceRecords[0].Value')"
resourceValWest="$(echo "$westRecord" | jq '.ResourceRecords[0].Value')"
echo East Resource Value: $resourceValEast
echo West Resource Value: $resourceValWest

# Pull Weights for each region
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

echo
echo Creating policy file to push changes back to $recordName
echo


# Record Name
sed "s/RECORDNAME/$nameString/g" policy-template.json > policy.json

# Set ID
sed -i "s/SETID_EAST/$setIDEast/g" policy.json
sed -i "s/SETID_WEST/$setIDWest/g" policy.json

# Type
sed -i "s/TYPE_EAST/$typeEast/g" policy.json
sed -i "s/TYPE_WEST/$typeWest/g" policy.json

# TTL
sed -i "s/TTL_EAST/$ttlEast/g" policy.json
sed -i "s/TTL_WEST/$ttlWest/g" policy.json

# Weight
sed -i "s/WEIGHT_EAST/$newEastWeight/g" policy.json
sed -i "s/WEIGHT_WEST/$newWestWeight/g" policy.json

# Resources
sed -i "s/RESOURCE_VALUE_EAST/$resourceValEast/g" policy.json
sed -i "s/RESOURCE_VALUE_WEST/$resourceValWest/g" policy.json


echo Executing aws command to update weights to new weights
aws route53 change-resource-record-sets --hosted-zone-id $hostedZoneID --change-batch file://policy.json

echo
echo -----------------------
echo Ending Traffic Switcher
echo -----------------------
echo