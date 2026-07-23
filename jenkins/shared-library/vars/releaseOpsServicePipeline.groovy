def call(Map config = [:]) {
    requireConfig(config, [
        'serviceName',
        'appDirectory',
        'dockerfile',
        'awsRegion',
        'awsAccountId',
        'awsRoleName',
        'ecrRegistry',
        'ecrRepository',
        'gitOpsValuesFile',
        'gitOpsEnvironment',
        'gitHubTokenCredentialId'
    ])

    String serviceName = config.serviceName
    String appDirectory = config.appDirectory
    String dockerfile = config.dockerfile
    String agentLabel = config.get('agentLabel', 'linux-docker')
    String sonarInstallation = config.get('sonarInstallation', 'sonarqube')

    pipeline {
        agent {
            label "${agentLabel}"
        }

        options {
            timestamps()
            ansiColor('xterm')
            disableConcurrentBuilds(abortPrevious: true)
            buildDiscarder(logRotator(numToKeepStr: '30', artifactNumToKeepStr: '10'))
            timeout(time: 45, unit: 'MINUTES')
            skipDefaultCheckout(true)
        }

        environment {
            SERVICE_NAME = "${serviceName}"
            APP_DIRECTORY = "${appDirectory}"
            DOCKERFILE = "${dockerfile}"
            AWS_REGION = "${config.awsRegion}"
            ECR_REGISTRY = "${config.ecrRegistry}"
            ECR_REPOSITORY = "${config.ecrRepository}"
        }

        stages {
            stage('Checkout') {
                steps {
                    retry(2) {
                        checkout scm
                    }
                    script {
                        env.SHORT_SHA = sh(
                            script: 'git rev-parse --short=12 HEAD',
                            returnStdout: true
                        ).trim()
                        env.IMAGE_TAG = "${env.SERVICE_NAME}-${env.SHORT_SHA}"
                        env.IMAGE_URI = "${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}:${env.IMAGE_TAG}"
                    }
                }
            }

            stage('Compile And Test') {
                steps {
                    dir(appDirectory) {
                        sh './mvnw --batch-mode --no-transfer-progress clean verify'
                    }
                }
                post {
                    always {
                        junit(
                            allowEmptyResults: true,
                            testResults: "${appDirectory}/**/target/*-reports/*.xml"
                        )
                    }
                }
            }

            stage('Static Analysis') {
                steps {
                    withSonarQubeEnv(sonarInstallation) {
                        dir(appDirectory) {
                            sh './mvnw --batch-mode --no-transfer-progress sonar:sonar'
                        }
                    }
                }
            }

            stage('Quality Gate') {
                options {
                    timeout(time: 10, unit: 'MINUTES')
                }
                steps {
                    waitForQualityGate abortPipeline: true
                }
            }

            stage('Build Candidate Image') {
                steps {
                    sh '''#!/usr/bin/env bash
                        set -euo pipefail
                        docker build \
                          --pull \
                          --file "${DOCKERFILE}" \
                          --tag "${IMAGE_URI}" \
                          "${APP_DIRECTORY}"
                    '''.stripIndent()
                }
            }

            stage('Scan And Create SBOM') {
                steps {
                    sh '''#!/usr/bin/env bash
                        set -euo pipefail
                        mkdir -p build/reports
                        trivy image \
                          --exit-code 1 \
                          --ignore-unfixed \
                          --severity HIGH,CRITICAL \
                          "${IMAGE_URI}"
                        syft "${IMAGE_URI}" \
                          --output cyclonedx-json=build/reports/sbom.cdx.json
                    '''.stripIndent()
                }
            }

            stage('Publish Immutable Candidate') {
                when {
                    anyOf {
                        branch 'main'
                        buildingTag()
                    }
                }
                steps {
                    withAWS(
                        role: config.awsRoleName,
                        roleAccount: config.awsAccountId,
                        region: config.awsRegion,
                        roleSessionName: "jenkins-${env.BUILD_NUMBER}",
                        duration: 1800
                    ) {
                        sh '''#!/usr/bin/env bash
                            set -euo pipefail
                            set +x
                            aws ecr get-login-password --region "${AWS_REGION}" |
                              docker login \
                                --username AWS \
                                --password-stdin "${ECR_REGISTRY}"
                            set -x
                            docker push "${IMAGE_URI}"
                            IMAGE_DIGEST="$(
                              aws ecr describe-images \
                                --repository-name "${ECR_REPOSITORY}" \
                                --image-ids imageTag="${IMAGE_TAG}" \
                                --query 'imageDetails[0].imageDigest' \
                                --output text
                            )"
                            test -n "${IMAGE_DIGEST}"
                            printf '%s' "${IMAGE_DIGEST}" > build/image-digest.txt
                        '''.stripIndent()
                    }
                }
            }

            stage('Propose GitOps Promotion') {
                when {
                    branch 'main'
                }
                steps {
                    script {
                        String imageDigest = readFile('build/image-digest.txt').trim()
                        openGitOpsPromotion(
                            serviceName: serviceName,
                            environment: config.gitOpsEnvironment,
                            valuesFile: config.gitOpsValuesFile,
                            imageRepository: "${config.ecrRegistry}/${config.ecrRepository}",
                            imageDigest: imageDigest,
                            gitHubTokenCredentialId: config.gitHubTokenCredentialId
                        )
                    }
                }
            }
        }

        post {
            always {
                archiveArtifacts(
                    allowEmptyArchive: true,
                    artifacts: 'build/reports/**,build/image-digest.txt',
                    fingerprint: true
                )
                deleteDir()
            }
            unsuccessful {
                echo "Pipeline failed. Notify the owning team with the stage and build URL."
            }
        }
    }
}

private void requireConfig(Map config, List<String> requiredKeys) {
    List<String> missing = requiredKeys.findAll { !config[it] }
    if (!missing.isEmpty()) {
        error("Missing releaseOpsServicePipeline configuration: ${missing.join(', ')}")
    }
}
