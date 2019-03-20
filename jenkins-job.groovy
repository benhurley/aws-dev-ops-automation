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
            ./rollback.sh
         '''
      }
    }
   }
}