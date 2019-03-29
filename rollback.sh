#!/bin/sh
#rollback.sh

# This script handles the rollback process automatically for the east and west regions.
# The script will check to see if a revert is necessary, and if so, will perform the revert
# on the codebase (effectively rolling back to the last commit). If a revert has already been
# done, it will deploy the rollback build to the target environment. It will also pause for log
# validation and terminate if the user finds an error.

# Main script starts here

echo --------------------
echo Initiating Rollback
echo --------------------
echo

# Read in current region and branch
branch=$1

echo Switching to $branch
echo
git checkout $branch

echo Checking last commit message for Revert
revertCheck="$(git log -1 --format=%s)"
echo Last Commit: $revertCheck

if [[ $revertCheck = *Revert* ]] ;
then
    echo
    echo REVERT FOUND: Codebase has already reverted, manually deploy to environment.
    echo
    echo --------------------
    echo End Rollback
    echo --------------------
    echo
    exit 1

else
    echo Checking last commit message for Merge
    echo

    if [[ $revertCheck = *Merge* ]] ;
    then
        echo MERGE FOUND. The following merge will now be reverted:
        echo
        git log -1
        echo
        git revert --no-edit -m 1 HEAD
        echo
        echo Pushing changes to remote repository.
        echo
        git push --set-upstream origin $branch
        echo
    else
        echo
        echo No merge found. Will not rollback.
        echo
    fi
fi

echo ------------
echo End Rollback
echo ------------
echo