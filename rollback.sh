#!/bin/sh
#rollback.sh

# This script handles the rollback process automatically for the east and west regions.
# The script will check to see if a revert is necessary, and if so, will perform the revert
# on the codebase (effectively rolling back to the last commit). If a revert has already been
# done, it will deploy the rollback build to the target environment. It will also pause for log
# validation and terminate if the user finds an error.

echo --------------------
echo Initiating Rollback
echo --------------------
echo
# Determine Region
#TODO hard-coding west for now, need to read param
myRegion="west"

otherRegion=""

echo Current Region: $myRegion
echo

# determine other region
if [[ $myRegion = "west" ]];
then 
    otherRegion="east"
    else
    otherRegion="west"
fi

# Pick a branch to switch to
echo Switching to Pariveda Branch
echo
#git checkout pariveda

echo Pulling updates from remote repository
echo
#git pull

echo Checking last commit message for Revert
revertCheck="$(git log -1 --format=%s)"
echo Last Commit: $revertCheck
if [[ $revertCheck = *Revert* ]] ;
then
    echo
    echo REVERT FOUND: Codebase has already reverted, deploying HEAD to $myRegion
    #deploy HEAD to current environment

    else    
    echo

    #TODO check for a merge before going forward
    echo No revert found. Reverting most-recent commit:
    echo
    git log -1
    # git revert -m 1 HEAD
    # deploy 
    echo Pushing changes to remote repository
    #git push
fi
# else we are in east region (edge case)

echo
echo Routing 10% of traffic to $myRegion
#TODO add that functionality
echo
echo Pause for examining CloudWatch Logs, enter 'y' to continue
read ans1
if [[ $ans1 = y ]]; 
then 
    echo
    echo Routing 100% of traffic to $myRegion
    #TODO add that functionality
    echo
    echo Pause for examining CloudWatch Logs, enter 'y' to continue
    read ans2

    if [[ $ans2 = y ]]; 
    then 
        echo Rollback complete, re-routing 100% of traffic back to $otherRegion.
        #TODO add that functionality
    else
        echo Error found. Re-routing 100% of traffic back to $otherRegion for manual debug.
        #TODO add that functionality
    fi
else   
    echo Error found. Re-routing 100% of traffic back to $otherRegion for manual debug.
    #TODO add that functionality
fi
