def branch = getGitBranchName()
def getGitBranchName() {
   return env.BRANCH_NAME
}

pipeline {
 agent { label 'master'}
   stages{
   stage('Rollback'){
     steps {
         sh ''' 
            echo Initiating Rollback
            echo
            echo Pulling any changes from remote repo
            git pull
            echo
            echo Rolling back last commit:
            git log -1
            echo
            git revert -m 1 HEAD
            echo
            echo Pushing changes to remote repo
            git push
         '''
      }
    }
   }
}