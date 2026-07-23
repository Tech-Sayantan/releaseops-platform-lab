def call(Map config = [:]) {
    List<String> required = [
        'serviceName',
        'environment',
        'valuesFile',
        'imageRepository',
        'imageDigest',
        'gitHubTokenCredentialId'
    ]
    List<String> missing = required.findAll { !config[it] }
    if (!missing.isEmpty()) {
        error("Missing openGitOpsPromotion configuration: ${missing.join(', ')}")
    }

    if (!(config.serviceName ==~ /[a-z0-9][a-z0-9-]{0,62}/)) {
        error('serviceName contains unsupported characters')
    }
    if (!(config.environment ==~ /[a-z0-9][a-z0-9-]{0,30}/)) {
        error('environment contains unsupported characters')
    }
    if (!(config.imageDigest ==~ /sha256:[0-9a-f]{64}/)) {
        error('imageDigest is not an immutable sha256 digest')
    }

    String promotionBranch =
        "gitops/${config.environment}/${config.serviceName}-${env.BUILD_NUMBER}"

    withCredentials([
        string(
            credentialsId: config.gitHubTokenCredentialId,
            variable: 'GH_TOKEN'
        )
    ]) {
        withEnv([
            "PROMOTION_BRANCH=${promotionBranch}",
            "VALUES_FILE=${config.valuesFile}",
            "IMAGE_REPOSITORY=${config.imageRepository}",
            "IMAGE_DIGEST=${config.imageDigest}",
            "SERVICE_NAME=${config.serviceName}",
            "TARGET_ENVIRONMENT=${config.environment}"
        ]) {
            sh '''#!/usr/bin/env bash
                set -euo pipefail
                gh auth setup-git
                git switch -C "${PROMOTION_BRANCH}"
                python3 scripts/update_gitops_image.py \
                  --file "${VALUES_FILE}" \
                  --repository "${IMAGE_REPOSITORY}" \
                  --digest "${IMAGE_DIGEST}"
                git diff --check
                git add "${VALUES_FILE}"

                if git diff --cached --quiet; then
                  echo "GitOps already points at this digest; no PR is required."
                  exit 0
                fi

                git config user.name "releaseops-jenkins"
                git config user.email "releaseops-jenkins@users.noreply.github.com"
                git commit \
                  -m "chore(gitops): promote ${SERVICE_NAME} to ${TARGET_ENVIRONMENT}"
                git push --set-upstream origin "${PROMOTION_BRANCH}"
                gh pr create \
                  --title "Promote ${SERVICE_NAME} to ${TARGET_ENVIRONMENT}" \
                  --body "Promotes ${IMAGE_REPOSITORY}@${IMAGE_DIGEST}. Review and merge this PR for Argo CD reconciliation." \
                  --label gitops \
                  --label promotion
            '''.stripIndent()
        }
    }
}
