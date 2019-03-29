#!/bin/sh
# whichState.sh

# This script determines which situation we are in to relay to Jenkins:
# 1. Normal dDployment - "deploy"
# 2. Rollback (West only) - "rollbackWest"
# 3. Rollback (East and West) - "rollbackBoth"

# Incoming Parameters
# 1. Hosted Zone ID
# 2. Record Set Name
# 3. Branch Name

echo
echo ------------------------
echo Initiating State Tracker
echo ------------------------
echo

# Initialize incoming variables
hostedZoneID=$1
recordName=$2
branch=$3

echo Switching to $branch
echo
git checkout $branch

# Check last commit to see what is going on
echo Checking last commit message
commitCheck="$(git log -1 --format=%s)"

if [[ $commitCheck = *Revert* ]] ;
then
    # Rollback Case
    # Check where current traffic is going
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

    # Pull Weights for each region
    echo
    echo Current Route53 weights for each region in $recordName:
    eastWeight="$(echo "$eastRecord" | jq '.Weight')"
    westWeight="$(echo "$westRecord" | jq '.Weight')"
    echo East Weight: $eastWeight
    echo West Weight: $westWeight

    if [[ westWeight = 0 ]] ;
    then
        # Only Rollback West
        echo "rollbackWest" > currentstate.txt
    elif [[ eastWeight = 0 ]] ;
    then
        # Rollback East and West
        echo "rollbackBoth" > currentstate.txt
    else
        echo Could not find region without live traffic
        exit 1
    fi
else
    # Normal Deployment Case
    echo "deploy" > currentstate.txt
fi

echo
echo --------------------
echo Ending State Tracker
echo --------------------
echo