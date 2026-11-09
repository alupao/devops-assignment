# DevOps Terraform assignment

This project covers all five assignment tasks. Start with the setup below for a fresh checkout and two AWS accounts. No VPC, subnet, SSH key pair, state bucket, lock table, ECR repository or ECS service needs to be created beforehand.

Task explanations and the corrected Task 5 code are in [NOTES.md](docs/NOTES.md). The submitted CI policy is in [docs/ci-policy.json](docs/ci-policy.json); its account ID is a placeholder. Terraform builds the deployed policy from actual resource ARNs.

## What gets created

| Location | Resources |
|---|---|
| Account A | Network, five EC2 instances and SSH key pairs, IAM users/groups/roles, ECR, ECS and an artifacts bucket. |
| Account B | A dedicated S3 bucket and roleC, trusted only by Account A's roleB. |
| Backend in Account A | An encrypted, versioned S3 state bucket and a DynamoDB lock table. |

`terraform/bootstrap/` creates the backend. `terraform/deployment/` deploys both accounts together, using the modules under `terraform/modules/`.

The five instances are configured as follows:

| Name | Type | Encrypted root disk | IOPS |
|---|---|---|---|
| legacy | t2.micro | standard, 16 GiB | Default |
| general | t3.micro | gp2, 24 GiB | Default |
| application | t3.small | gp3, 32 GiB | Default |
| database | m5.large | io1, 40 GiB | 1,000 |
| critical | m5.xlarge | io2, 50 GiB | 3,000 |

All instance types, disk types, disk sizes and key pairs must be distinct. `critical` has `prevent_destroy = true`.

## 1. Install tools and configure AWS access

Use Terraform **1.17.1**, AWS CLI v2 and GnuPG. Docker and `jq` are needed for the optional CI smoke test in Step 8. Keep the Terraform lockfiles; the tested providers are AWS **6.72.0**, TLS **4.4.2** and local **2.9.1**.

Run commands from the project root. Stop if a command fails and resolve the error before continuing.

Configure two non-root AWS profiles using their access key IDs and secret access keys. When prompted, set the default region to `ap-south-1` and output format to `json`:

```sh
aws configure --profile assignment-account-a
aws configure --profile assignment-account-b
aws --profile assignment-account-a sts get-caller-identity
aws --profile assignment-account-b sts get-caller-identity
terraform version
```

The profile names are local labels; use the same names in your input files. Verify that STS reports two different intended accounts and that neither ARN ends in `:root`.

The Account A operator needs permission to provision EC2/VPC resources, key pairs, IAM, S3, DynamoDB, ECR, ECS and CloudWatch Logs, including `iam:PassRole` and `iam:CreateServiceLinkedRole`. The AMI lookup also needs `ssm:GetParameter` and EC2 describe access. The Account B operator needs IAM and S3 provisioning permissions. These are operator permissions; the restricted `ci` user is created later by Terraform.

Use **ap-south-1**. Applying creates billable EC2, EBS and storage resources, including provisioned-IOPS disks.

IAM names are fixed by the assignment: users `engine`, `ci`, `alice`, `bob`; groups `group1`, `group2`; roles `roleA`, `roleB` in Account A and `roleC` in Account B. Check for conflicts in your test accounts. If those names are owned by another deployment, resolve ownership before applying; changing `name_prefix` will not rename them. Terraform does not automatically adopt existing resources.

## 2. Prepare PGP recipients and private inputs

PGP encrypts the generated IAM access secrets and console passwords. It is separate from the EC2 SSH keys, which Terraform generates automatically.

Use each recipient's public PGP key. For your own test, you may use a public key you control for all four users. If you do not have one, run `gpg --full-generate-key`, choose an RSA key with encryption capability, and protect the private key with a passphrase. List fingerprints and export the chosen public key as base64-encoded binary data:

```sh
gpg --list-keys --with-fingerprint
gpg --export YOUR_PUBLIC_KEY_FINGERPRINT | base64 | tr -d '\n'
```

Replace `YOUR_PUBLIC_KEY_FINGERPRINT` with the fingerprint you verified. Copy the resulting public-key text into the relevant `user_pgp_keys` values below. An ASCII-armored key, file path or private key will not work. Keep the private recipient available until its IAM credentials have been revoked.

Keep each root's working files beside its Terraform code. Terraform loads `terraform.tfvars.json` automatically; input files, backend settings, state, plans and `.terraform/` are ignored by Git. Before creating inputs, use:

```sh
umask 077
```

Create `terraform/bootstrap/terraform.tfvars.json` with the following content. Replace the dummy account ID with the independently verified Account A ID:

```json
{
  "aws_region": "ap-south-1",
  "aws_profile": "assignment-account-a",
  "account_id": "000000000000",
  "owner": "assignment"
}
```

Create `terraform/deployment/terraform.tfvars.json`. Replace both account IDs and all four PGP values:

```json
{
  "account_a_id": "000000000000",
  "account_a_profile": "assignment-account-a",
  "account_b_id": "111111111111",
  "account_b_profile": "assignment-account-b",
  "aws_region": "ap-south-1",
  "owner": "assignment",
  "name_prefix": "devops-assignment",
  "ami_id": null,
  "user_pgp_keys": {
    "engine": "REPLACE_WITH_BASE64_PUBLIC_KEY",
    "ci": "REPLACE_WITH_BASE64_PUBLIC_KEY",
    "alice": "REPLACE_WITH_BASE64_PUBLIC_KEY",
    "bob": "REPLACE_WITH_BASE64_PUBLIC_KEY"
  },
  "instances": {
    "legacy": {
      "instance_type": "t2.micro", "root_volume_type": "standard", "root_volume_size": 16,
      "environment": "assignment", "owner": "assignment"
    },
    "general": {
      "instance_type": "t3.micro", "root_volume_type": "gp2", "root_volume_size": 24,
      "environment": "assignment", "owner": "assignment"
    },
    "application": {
      "instance_type": "t3.small", "root_volume_type": "gp3", "root_volume_size": 32,
      "environment": "assignment", "owner": "assignment"
    },
    "database": {
      "instance_type": "m5.large", "root_volume_type": "io1", "root_volume_size": 40,
      "root_iops": 1000, "environment": "assignment", "owner": "assignment"
    },
    "critical": {
      "instance_type": "m5.xlarge", "root_volume_type": "io2", "root_volume_size": 50,
      "root_iops": 3000, "environment": "assignment", "owner": "assignment", "protected": true
    }
  }
}
```

Set both files to `0600`:

```sh
chmod 600 terraform/bootstrap/terraform.tfvars.json terraform/deployment/terraform.tfvars.json
```

After destroying a test deployment, replace any test PGP public recipients whose private keys have been removed before deploying again. Do not put AWS credentials, SSH private keys or PGP private keys in them. Terraform discovers actual account IDs through STS and checks them against your expected IDs. With `ami_id: null`, it discovers an Amazon-owned x86_64 Amazon Linux AMI through SSM.

The full input definitions are in [bootstrap/variables.tf](terraform/bootstrap/variables.tf) and [deployment/variables.tf](terraform/deployment/variables.tf).

## 3. Create the backend

This step creates the S3 bucket and DynamoDB table. You do not need backend settings from another person.

For an installation you previously deployed, use the repeat-run instructions below instead. If `terraform/bootstrap/backend.tf` or private initialization/state files are present, inspect their ownership before continuing. Do not overwrite an active backend or start a second state for resources that already exist.

For a fresh checkout, leave `terraform/bootstrap/backend.tf` absent. Bootstrap initially uses Terraform's default local state at `terraform/bootstrap/terraform.tfstate`:

```sh
terraform -chdir=terraform/bootstrap init -input=false -lockfile=readonly
terraform -chdir=terraform/bootstrap validate
terraform -chdir=terraform/bootstrap plan -out=bootstrap.tfplan
terraform -chdir=terraform/bootstrap show bootstrap.tfplan
```

Review the six-resource creation plan and its costs. When approved, apply it:

```sh
terraform -chdir=terraform/bootstrap apply bootstrap.tfplan
```

After success, delete the consumed plan and generate backend settings from the resources just created:

```sh
rm terraform/bootstrap/bootstrap.tfplan
terraform -chdir=terraform/bootstrap output -raw bootstrap_backend_hcl \
  > "terraform/bootstrap/backend.hcl"
terraform -chdir=terraform/bootstrap output -raw deployment_backend_hcl \
  > "terraform/deployment/backend.hcl"
```

## 4. Move bootstrap state to S3

Create `terraform/bootstrap/backend.tf` to switch the local state from Step 3 to S3:

```sh
cat > terraform/bootstrap/backend.tf <<'HCL'
terraform {
  backend "s3" {
    key     = "assignment/bootstrap/terraform.tfstate"
    encrypt = true
  }
}
HCL

terraform -chdir=terraform/bootstrap init -migrate-state \
  -backend-config=backend.hcl
terraform -chdir=terraform/bootstrap plan
```

Confirm copying the existing state when prompted. Verify that the last plan reports **no changes** before removing obsolete local state copies. Do not use `-force-copy` or bypass locks.

The remote state keys are `assignment/bootstrap/terraform.tfstate` and `assignment/deployment/terraform.tfstate`. DynamoDB locking is used because Task 2 requires it. The operator who created the backend needs S3 state-object and DynamoDB lock access for later runs. `backend_access_policy_json` provides a backend-only policy if an administrator needs to grant that access to another operator; it does not grant workload provisioning permissions.

## 5. Check the ECS service-linked role

ECS uses the AWS-managed service-linked role `AWSServiceRoleForECS`. Check Account A:

```sh
aws --profile assignment-account-a iam get-role --role-name AWSServiceRoleForECS
```

If the result is `NoSuchEntity`, create it:

```sh
aws --profile assignment-account-a iam create-service-linked-role \
  --aws-service-name ecs.amazonaws.com
aws --profile assignment-account-a iam wait role-exists --role-name AWSServiceRoleForECS
```

For `AccessDenied`, fix the operator's permissions instead of treating the role as missing. Checking/creating the role before the workload gives IAM time to propagate it. If ECS still reports a first-use role propagation error, wait and generate a fresh plan before retrying the failed apply. Do not add broad permissions to the task roles.

## 6. Deploy both accounts

Initialize the deployment root and validate it:

```sh
terraform -chdir=terraform/deployment init -input=false -lockfile=readonly \
  -backend-config=backend.hcl
terraform fmt -check -recursive terraform
terraform -chdir=terraform/deployment validate
terraform -chdir=terraform/deployment plan -lock-timeout=60s \
  -out=assignment.tfplan
terraform -chdir=terraform/deployment show assignment.tfplan
```

A fresh deployment should propose **73 creates**, including 58 AWS resources and 15 TLS/local resources. It creates the network, keys, users, roles, buckets and CI infrastructure together. Review the accounts, resource names, disk settings and costs, then apply the approved plan:

```sh
terraform -chdir=terraform/deployment apply assignment.tfplan
```

After success, remove the plan:

```sh
rm terraform/deployment/assignment.tfplan
```

Keep only the plan being applied. After a failed or partial apply, inspect the error and generate a new plan against the resulting state; do not reuse the consumed plan.

## 7. Verify the deployment and key reuse

```sh
terraform -chdir=terraform/deployment output instance_ids
terraform -chdir=terraform/deployment output private_ips
terraform -chdir=terraform/deployment output role_arns
terraform -chdir=terraform/deployment output selected_ami_id
terraform -chdir=terraform/deployment output console_sign_in_url
terraform -chdir=terraform/deployment output -raw ci_policy_json
```

Use the instance IDs to check the EC2 console or `aws ec2 describe-instance-status --instance-ids ...` with Account A's profile and `--region ap-south-1`. Wait for both system and instance checks to pass.

Five SSH pairs appear under `terraform/deployment/keypairs-output/`, named `<instance>.pem` and `<instance>.pub`. Private files are OpenSSH format. Files use `0600`; new directories use `0700`. Terraform stores the private keys in state too, so state must be protected.

Pin the reviewed `selected_ami_id` in the private `ami_id` input. Then repeat Step 6's plan/apply using the same backend, instance names, prefix and algorithm. An unchanged run should report no changes and reuse the same SSH keys. Missing local files are restored from state. Do not delete state to reset a run.

Instances have private IPs, no inbound security-group rules and no SSM instance profile. There is no public SSH route; the assignment does not provision a bastion or VPN.

Alice and Bob have console login profiles and CLI keys; engine and CI have CLI keys only. An administrator must enroll MFA for Alice/Bob under **IAM → Users → Security credentials → Assign MFA device** before they can assume roleA/roleB. Their initial console passwords require a password change. Generated secrets/passwords are PGP-encrypted in the `encrypted_credentials` output; only the matching private recipient can decrypt them.

## 8. Optional CI smoke test

This test starts one billable 0.25-vCPU/0.5-GiB Fargate task, then returns the service to zero tasks. It leaves one test image and a task-definition revision. Use your own image for a real release; the commands below use Alpine solely to test image push and deployment.

Install Docker and `jq`, start Docker, and confirm `docker version` and `jq --version` work. Save the encrypted credentials and CI inputs in the deployment directory:

```sh
terraform -chdir=terraform/deployment output -json encrypted_credentials \
  > "terraform/deployment/ci-credentials.json"
terraform -chdir=terraform/deployment output -json ci_targets \
  > "terraform/deployment/ci-targets.json"
terraform -chdir=terraform/deployment output -json task_definition_template \
  > "terraform/deployment/ci-task-template.json"
```

Run this block in Bash. GnuPG may prompt for the recipient's passphrase. Credentials stay in the subshell and are not printed; do not run with shell tracing enabled. The exit handler scales back to zero and logs Docker out even if a later test command fails. Check its output for scale-down errors.

```sh
(
set -euo pipefail
CI_RUNTIME="$(pwd)/terraform/deployment"
unset AWS_PROFILE AWS_SESSION_TOKEN
AWS_ACCESS_KEY_ID="$(jq -er '.ci.access_key_id' "$CI_RUNTIME/ci-credentials.json")"
AWS_SECRET_ACCESS_KEY="$(jq -er '.ci.encrypted_secret' "$CI_RUNTIME/ci-credentials.json" | base64 --decode | gpg --decrypt)"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=ap-south-1
export AWS_REGION=ap-south-1
export DOCKER_CONFIG="$CI_RUNTIME/.docker-auth"
mkdir -p "$DOCKER_CONFIG"
CI_REPOSITORY="$(jq -r '.repository_url' "$CI_RUNTIME/ci-targets.json")"
CI_REGISTRY="${CI_REPOSITORY%%/*}"
CI_CLUSTER="$(jq -r '.cluster_arn' "$CI_RUNTIME/ci-targets.json")"
CI_SERVICE="$(jq -r '.service_name' "$CI_RUNTIME/ci-targets.json")"
CI_TASK=""
trap 'if [ -n "$CI_TASK" ]; then aws ecs update-service --cluster "$CI_CLUSTER" --service "$CI_SERVICE" --task-definition "$CI_TASK" --desired-count 0 >/dev/null || printf "Scale-down failed; use the operator profile to stop the test.\n" >&2; fi; docker logout "$CI_REGISTRY" >/dev/null' EXIT
aws ecr get-login-password | docker login --username AWS --password-stdin "$CI_REGISTRY"
docker pull --platform linux/amd64 alpine:3.21
docker tag alpine:3.21 "$CI_REPOSITORY:latest"
docker push "$CI_REPOSITORY:latest"
jq --arg image "$CI_REPOSITORY:latest" \
  '.containerDefinitions[0].image = $image | .containerDefinitions[0].command = ["sh", "-c", "echo assignment-ci-test; sleep 600"]' \
  "$CI_RUNTIME/ci-task-template.json" > "$CI_RUNTIME/ci-task-release.json"
CI_TASK="$(aws ecs register-task-definition --cli-input-json "file://$CI_RUNTIME/ci-task-release.json" --query taskDefinition.taskDefinitionArn --output text)"
aws ecs update-service --cluster "$CI_CLUSTER" --service "$CI_SERVICE" --task-definition "$CI_TASK" --desired-count 1 >/dev/null
aws ecs wait services-stable --cluster "$CI_CLUSTER" --services "$CI_SERVICE"
aws ecs describe-services --cluster "$CI_CLUSTER" --services "$CI_SERVICE" \
  --query 'services[].{Desired:desiredCount,Running:runningCount,Pending:pendingCount}'
)
```

A successful smoke test reports one running task before exit. After the block exits, use Account A's operator profile to check that desired/running/pending settle at zero:

```sh
aws --profile assignment-account-a --region ap-south-1 ecs describe-services \
  --cluster devops-assignment --services devops-assignment-app \
  --query 'services[].{Desired:desiredCount,Running:runningCount,Pending:pendingCount}'
```

If scale-down fails, run `aws --profile assignment-account-a --region ap-south-1 ecs update-service --cluster devops-assignment --service devops-assignment-app --desired-count 0`, then check counts again. If you changed `name_prefix`, use the cluster/service names from `ci-targets.json`. Include the approved task-definition ARN even for scale-only requests: the CI policy requires it. Terraform leaves service revisions and task counts under CI control after the first release.

## Repeat runs and another operator

For resources already managed by this project, use their authoritative state instead of repeating fresh bootstrap creation. Configure both AWS profiles and place the matching `terraform.tfvars.json` and `backend.hcl` files in each root. Initialize the deployment with Step 6. To initialize bootstrap on another machine, create its S3 block from Step 4 and run `init -backend-config=...` with the matching bootstrap backend HCL. Do not replace it with a local backend.

A new operator also needs state-bucket and lock-table access. The backend files contain settings, not credentials or permissions. Do not point a different input configuration at a populated state, or use a new state to adopt resources that already exist.

## Recorded live verification

The following checks were completed on **2026-11-10 IST**, using Terraform 1.17.1 and the locked providers. These are results from the original test run, not resources or credentials supplied to the reviewer.

| Check | Result |
|---|---|
| Configuration | Formatting and both roots' validation passed. |
| Backend | Six resources created; versioning, encryption, HTTPS-only policy, public-access blocking and lock-table deletion protection verified. State migration and a no-change bootstrap plan passed. |
| Workload | 73 resources created across the intended accounts using canonical state keys. |
| EC2/disks | Original five types passed both health checks; tags, private-only addressing and encrypted disk configurations verified. |
| Key reuse | Five AWS pairs matched state and local files. Second apply made zero changes; all ten file hashes stayed unchanged. |
| IAM | Four credentials authenticated; groups, CLI-only users, human password decryption and MFA-required denial verified. |
| Cross-account | Engine → roleB → roleC listed, wrote, read and deleted a test object. Engine → roleC directly and CI → roleB were denied. |
| CI | Artifact read allowed and write denied; image push, task registration, Fargate RUNNING state and test log verified. ECS returned to 0/0/0. |
| Test files/plans | Test objects, consumed plans and plan-output logs removed. |

Interactive console sign-in/MFA enrollment and guest SSH login were not tested. After these tests, the workload and backend were destroyed through reviewed plans. Both accounts were checked for remaining assignment resources; none remained. The test image, task revisions, service-linked role, generated keys and temporary credentials were removed.

## Cleanup and submission

Review a destroy plan before removing resources. The protected EC2 instance, state bucket and lock table have `prevent_destroy`; DynamoDB also has deletion protection. Review these guards before teardown. Remove workload resources before the backend, and keep state until the resources it tracks are gone. Versioned objects and ECR images need deliberate cleanup; the configuration does not force-empty buckets or repositories.

Submit source, lockfiles, the assignment document, policy JSON and task notes. Exclude ignored working files: `terraform.tfvars.json`, `backend.hcl`, generated bootstrap `backend.tf`, `.terraform/`, state, plans, CI output JSON, Docker credentials and `keypairs-output/`.
