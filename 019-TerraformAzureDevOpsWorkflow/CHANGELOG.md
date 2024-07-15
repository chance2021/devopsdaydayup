# Changelog

All notable changes to this application should be documented in this changelog file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and the version format adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)


## [0.1.0] 2024-06-24
### Updated
- Build Java code in Dockerfile
- Pass over the image tag # from build job to deploy job
- Complete the build/deploy process (Build: Checkout source code -> Maven/Ant/Gradle build -> PUblish Test Results -> Run Veracode Scan -> Docker Build -> Trivy Scan -> Publish Trivy Scan Result -> Docker push. Deploy: Update Image tag in Helm Value.yaml -> Donwload Secrets -> Replace tokens -> Deploy Helm Chart)
- 

## [0.0.1] 2024-05-19

### Added

- Requirement: Small startup company which only one development environment to star an application development
- Initiate a CICD pipeline only including java compile, publish artifacts, download artifacts and deploy to an Azure Function app.