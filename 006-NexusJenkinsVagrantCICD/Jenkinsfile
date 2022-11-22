pipeline {
  agent any
  tools {
      maven "m3"
  }
  environment {
      NEXUS_VERSION = "nexus3"
      NEXUS_PROTOCOL = "http"
      NEXUS_URL = "nexus:8081"
      NEXUS_REPOSITORY = "maven-nexus-repo"
      NEXUS_CREDENTIAL_ID = "nexus"
  }
  stages {
      stage("Clone code from VCS") {
          steps {
              git branch: 'main',
                  url: 'https://github.com/chance2021/devopsdaydayup.git'
              sh "pwd"
              sh "ls -lat"
          }
      }
      stage("Maven Build") {
          steps {
              script {
                  sh "cd 006-NexusJenkinsVagrantCICD"
                  sh "ls"
                  sh "pwd"
                  sh "cd 006-NexusJenkinsVagrantCICD && mvn clean package -DskipTests=true"
                  sh "pwd"
                  sh "ls"
              }
          }
      }
      stage("Publish to Nexus Repository Manager") {
          steps {
              script {
                  pom = readMavenPom file: "006-NexusJenkinsVagrantCICD/pom.xml";
                  filesByGlob = findFiles(glob: "006-NexusJenkinsVagrantCICD/target/*.${pom.packaging}");
                  echo "${filesByGlob[0].name} ${filesByGlob[0].path} ${filesByGlob[0].directory} ${filesByGlob[0].length} ${filesByGlob[0].lastModified}"
                  artifactPath = filesByGlob[0].path;
                  artifactExists = fileExists artifactPath;
                  if(artifactExists) {
                      echo "*** File: ${artifactPath}, group: ${pom.groupId}, packaging: ${pom.packaging}, version ${pom.version}";
                      nexusArtifactUploader(
                          nexusVersion: NEXUS_VERSION,
                          protocol: NEXUS_PROTOCOL,
                          nexusUrl: NEXUS_URL,
                          groupId: pom.groupId,
                          version: pom.version,
                          repository: NEXUS_REPOSITORY,
                          credentialsId: NEXUS_CREDENTIAL_ID,
                          artifacts: [
                              [artifactId: pom.artifactId,
                              classifier: '',
                              file: artifactPath,
                              type: pom.packaging],
                              [artifactId: pom.artifactId,
                              classifier: '',
                              file: "006-NexusJenkinsVagrantCICD/pom.xml",
                              type: "pom"]
                          ]
                      );
                  } else {
                      error "*** File: ${artifactPath}, could not be found";
                  }
              }
          }
      }
  }
}
