def branch = getGitBranchName()
def getGitBranchName() {
   return env.BRANCH_NAME
}

pipeline {
 agent { label 'ubuntu_with_docker' }
   stage('Rollback'){
     steps {
         sh ''' 
            echo Initiating Rollback
            echo
            echo
         '''
       }
     }
   }
 }
}