# Salesforce CI/CD Pipeline Documentation

## Overview

This document describes the automated Salesforce deployment pipeline implemented using GitHub Actions. The pipeline automates the validation and deployment of Salesforce metadata changes from pull requests through UAT and Production environments.

## Pipeline Architecture

### Workflow File
- **Location**: [.github/workflows/salesforce-pipeline.yml](.github/workflows/salesforce-pipeline.yml)
- **Trigger**: Pull requests to `main` branch with changes in `force-app/**`
- **Platform**: GitHub Actions on Ubuntu latest runners

## Pipeline Stages

The pipeline consists of four sequential jobs that ensure safe, tested deployments:

```
Pull Request → Validate UAT → Deploy UAT → Validate Production → Deploy Production → Auto-merge
```

### Stage 1: UAT Validation

**Job Name**: `validate-uat`

**Purpose**: Validates that changes can be successfully deployed to the UAT environment without actually deploying them.

**Key Steps**:
1. **Environment Setup**
   - Node.js 23
   - Salesforce CLI (cached for performance)
   - sfdx-git-delta plugin
   - Java (required for Salesforce CLI)

2. **Delta Detection**
   - Uses `sf sgd source delta` to identify changed metadata
   - Compares `HEAD` vs `HEAD^` (current vs previous commit)
   - Generates delta package in `changed-sources/` directory

3. **Validation**
   - Runs check-only deployment to UAT org
   - Executes `RunLocalTests` (all local Apex tests)
   - Does not modify the UAT environment

**Authentication**: Uses `SFDX_UAT_URL` GitHub secret

### Stage 2: UAT Deployment

**Job Name**: `deploy-uat`

**Dependencies**: Requires `validate-uat` to pass

**Purpose**: Deploys validated changes to the UAT environment for testing.

**Environment Protection**:
- Environment name: UAT
- URL: https://test.salesforce.com

**Key Steps**:
1. Same environment setup as validation
2. Regenerates delta package
3. Deploys to UAT with:
   - `RunLocalTests` test level
   - `--ignore-conflicts` flag to handle metadata conflicts
   - Full deployment (not check-only)

### Stage 3: Production Validation

**Job Name**: `validate-production`

**Dependencies**: Requires `deploy-uat` to complete

**Purpose**: Validates that changes can be deployed to Production without actually deploying.

**Key Steps**:
1. Environment setup (identical to UAT stages)
2. Delta package generation
3. Check-only deployment to Production org
4. Runs `RunLocalTests`

**Authentication**: Uses `SFDX_PROD_URL` GitHub secret

### Stage 4: Production Deployment

**Job Name**: `deploy-production`

**Dependencies**: Requires `validate-production` to pass

**Purpose**: Deploys changes to Production environment and auto-merges the PR.

**Environment Protection**:
- Environment name: PRODUCTION
- URL: https://login.salesforce.com

**Key Steps**:
1. Environment setup
2. Delta package generation
3. Deploy to Production with:
   - `RunLocalTests` test level
   - `--ignore-conflicts` flag
4. **Auto-merge PR**: Automatically merges the pull request using squash merge after successful deployment

## Key Features

### 1. Delta Deployments
- Uses `sfdx-git-delta` plugin to deploy only changed metadata
- Compares commits to identify modifications
- Reduces deployment time and risk

### 2. Performance Optimization
- **CLI Caching**: Salesforce CLI is cached to speed up builds
- Cache key based on `sfdx-project.json` hash
- Reduces installation time on subsequent runs

### 3. Environment Protection
- UAT and Production environments configured with protection rules
- Ensures proper approval gates (if configured in GitHub)
- Clear separation between testing and production

### 4. Test Execution
- **Test Level**: `RunLocalTests`
- Runs all Apex tests in the org (excluding managed packages)
- Ensures code coverage and quality standards

### 5. Auto-merge
- Automatically merges PRs after successful Production deployment
- Uses squash merge strategy for clean commit history
- Reduces manual overhead for approved changes

### 6. Security
- Authentication via encrypted GitHub secrets
- No credentials stored in repository
- SFDX URL-based authentication

## Required GitHub Secrets

The pipeline requires two secrets to be configured in the GitHub repository:

| Secret Name | Description | Usage |
|-------------|-------------|-------|
| `SFDX_UAT_URL` | Salesforce authentication URL for UAT org | UAT validation and deployment |
| `SFDX_PROD_URL` | Salesforce authentication URL for Production org | Production validation and deployment |

### How to Generate SFDX URLs

```bash
# Authenticate to your org
sf org login web --alias my-org

# Generate SFDX URL
sf org display --verbose --json --target-org my-org
```

## Permissions

The workflow requires the following GitHub permissions:

```yaml
permissions:
  contents: write        # For auto-merge
  pull-requests: write   # For PR operations
```

## Workflow Triggers

The pipeline triggers on:
- Pull request opened to `main` branch
- Pull request synchronized (new commits pushed)
- Changes affecting `force-app/**` directory

**Excluded**: Dependabot PRs (via `if: ${{ github.actor != 'dependabot[bot]' }}`)

## Dependencies

### Software
- **Node.js**: Version 23
- **Salesforce CLI**: Latest stable version
- **Java**: Default JDK (required for Salesforce CLI)

### Salesforce CLI Plugins
- `sfdx-git-delta`: For delta deployment capabilities

## Deployment Flow Example

```
1. Developer creates PR with Apex class changes
   ↓
2. Pipeline detects changes in force-app/
   ↓
3. Validate UAT: Check-only deployment ✓
   ↓
4. Deploy UAT: Full deployment ✓
   ↓
5. Validate Production: Check-only deployment ✓
   ↓
6. Deploy Production: Full deployment ✓
   ↓
7. Auto-merge PR ✓
```

## Error Handling

### Validation Failures
- If UAT validation fails, pipeline stops
- No deployment occurs
- Developer fixes issues and pushes new commit

### Deployment Failures
- If UAT deployment fails, Production stages are skipped
- If Production validation fails, Production deployment is skipped
- PR remains open for review

### Conflict Resolution
- `--ignore-conflicts` flag allows deployments to proceed with certain metadata conflicts
- Manual intervention may be required for complex conflicts

## Best Practices

### For Developers
1. **Test Locally**: Run local Apex tests before creating PR
2. **Small Changes**: Keep PRs focused on specific features/fixes
3. **Review Logs**: Check GitHub Actions logs for deployment details
4. **Monitor UAT**: Test changes in UAT before merging

### For Administrators
1. **Environment Protection**: Configure branch protection rules
2. **Secret Management**: Regularly rotate SFDX authentication URLs
3. **Test Coverage**: Maintain >75% code coverage in all orgs
4. **Monitoring**: Set up notifications for pipeline failures

## Troubleshooting

### Common Issues

#### Authentication Failures
```
Error: ERROR running org:login:sfdx-url
```
**Solution**: Update GitHub secrets with fresh SFDX URLs

#### Delta Generation Failures
```
Error: Cannot read property 'from' of undefined
```
**Solution**: Ensure adequate commit history (fetch-depth: 0)

#### Test Failures
```
Error: Test class failures
```
**Solution**: Fix failing tests and push new commit

#### Cache Issues
```
Warning: Salesforce CLI version mismatch
```
**Solution**: Clear cache or update cache key

## Monitoring and Metrics

### Key Metrics to Track
- **Deployment Success Rate**: Percentage of successful deployments
- **Pipeline Duration**: Time from PR creation to merge
- **Test Execution Time**: Duration of test runs
- **Deployment Frequency**: Number of deployments per day/week

### GitHub Actions Insights
- View workflow runs in **Actions** tab
- Monitor job durations and success rates
- Set up status badges for README

## Future Enhancements

### Potential Improvements
1. **Code Coverage Enforcement**: Require minimum coverage thresholds
2. **Slack Notifications**: Alert team on deployment status
3. **Rollback Capability**: Automated rollback on production failures
4. **Staging Environment**: Add intermediate staging environment
5. **PMD Analysis**: Static code analysis for code quality
6. **Custom Test Selection**: Allow specifying test classes in PR description

### Scaling Considerations
- Consider using self-hosted runners for faster builds
- Implement parallel test execution for large test suites
- Add manual approval gates for Production deployments
- Implement canary deployments for risk reduction

## Related Files

- [.github/workflows/salesforce-pipeline.yml](.github/workflows/salesforce-pipeline.yml) - Main workflow configuration
- [parsePR.js](parsePR.js) - PR parsing utility (legacy, not currently used)
- [pull_request_template.md](pull_request_template.md) - PR template
- [sfdx-project.json](sfdx-project.json) - Salesforce project configuration

## Support and Maintenance

### Updating the Pipeline
1. Modify workflow file in `.github/workflows/`
2. Test changes in a feature branch
3. Review logs carefully after deployment
4. Document changes in this file

### Getting Help
- GitHub Actions Documentation: https://docs.github.com/en/actions
- Salesforce CLI Guide: https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/
- sfdx-git-delta: https://github.com/scolladon/sfdx-git-delta

---

**Last Updated**: October 2025
**Pipeline Version**: 1.0
**Maintained By**: Development Team
