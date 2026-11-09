# Assignment notes

These notes explain the choices made for each task. Setup commands and test results are in the [README](../README.md).

## Task 1: Five EC2 instances

The `instances` map holds the configuration for all five machines. Each entry has a different instance type, root disk type, disk size and key pair. The disks use standard, gp2, gp3, io1 and io2 storage. Every instance gets `Name`, `Environment` and `Owner` tags, and the module returns maps of instance IDs and private IPs.

`critical` has `prevent_destroy = true` because it represents the machine that would be most costly to lose accidentally. The module uses two filtered `for_each` blocks: one for the protected instance and one for the other four. Terraform requires a literal lifecycle setting, so it cannot be switched on and off using `each.value.protected` in a single resource block. Both blocks still read the same input map.

The protection blocks deletion and changes that require replacement while the resource and lifecycle setting remain in the configuration. It does not prevent an in-place resize or replace a backup strategy.

Terraform generates five ED25519 key pairs using the same map keys as the instances. Keeping the same state and instance names reuses those keys on later applies. Private keys are stored in state as well as the local output directory, so both need restricted access.

The AMI lookup selects an Amazon-owned x86_64 Amazon Linux image. The subnet is placed in an availability zone that offers all five instance types. The instances have private IPs and no inbound access; using their SSH keys requires a suitable network route.

## Task 2: Remote state and locking

### What goes wrong with local state?

Terraform locks a local state file while it is in use. That helps when two processes share the same file, but two people working on different machines usually have separate copies. They can both apply changes without seeing each other's work, leaving duplicate resources or conflicting state.

### How does the backend fix this?

Both operators use the same S3 state object and DynamoDB lock table. Terraform acquires the lock with a conditional write using the `LockID` partition key. A second run waits for the lock or fails after its timeout instead of applying at the same time. This only works when everyone uses the same backend settings; it cannot stop manual AWS console changes.

The bucket has versioning, AES256 encryption, public-access blocking and a policy requiring HTTPS. The bucket and lock table have `prevent_destroy`, and the table also has AWS deletion protection. Bootstrap state uses `assignment/bootstrap/terraform.tfstate`; the workload uses `assignment/deployment/terraform.tfstate`.

DynamoDB locking is deprecated in newer Terraform versions, but it is used here because the assignment requires it.

## Task 3: IAM and cross-account access

Account A has two groups:

- `group1` contains `engine` and `ci`. Both have access keys and no console login profiles.
- `group2` contains `alice` and `bob`. Both have console passwords and access keys. They can change their own passwords and assume roleA or roleB after MFA authentication.

roleA allows all service actions and explicitly denies `iam:*`. The deny also blocks IAM actions such as `PassRole`. This meets the assignment, though broad access to other services still needs careful review in a real account.

roleB has one permission: assuming Account B's roleC. Engine can assume roleB; Alice and Bob can also assume it with MFA. CI has its own deployment policy and cannot assume roleB.

In Account B, roleC trusts only roleB's ARN. It has `s3:*` on one dedicated bucket and that bucket's objects. The deployment passes actual role ARNs between the account modules, so account IDs and role paths are not copied into trust policies by hand.

### Would engine and ci use IAM access keys in production?

Usually not. They are IAM users here to meet the assignment. An AWS-hosted application should use a workload role with temporary credentials. External CI should use OIDC to assume a role restricted to the expected repository and branch. People should use federation or IAM Identity Center with MFA and short-lived sessions.

If long-lived keys are unavoidable, they need secure storage, rotation and monitoring. For this assignment, PGP encrypts the generated IAM secrets and passwords for their recipients. It does not remove the need to protect Terraform state. MFA enrollment is handled by an administrator rather than storing MFA seeds in Terraform.

### Why trust roleB instead of Account A's root ARN?

An account root ARN in a trust policy delegates trust to the account. It does not mean only the root user can assume the role. Account A could authorize other identities to use that trust, which would be broader than the assignment allows.

Trusting roleB's ARN restricts access to that role and its sessions. Other users must first be allowed to assume roleB. AWS binds this trust to the role's internal identity, so deleting and recreating roleB may require updating roleC's trust policy even when the role name stays the same.

## Task 4: CI policy

The custom policy is in [ci-policy.json](ci-policy.json). The JSON uses a dummy account ID for submission; Terraform builds the deployed policy from actual resource ARNs. It can also be read through the `ci_policy_json` output.

| Operation | Allowed scope |
|---|---|
| Push an image | Layer and manifest operations on one ECR repository. Registry authentication uses `Resource: "*"` because that API does not support a repository ARN. |
| Register a task definition | Revisions of one ECS task family, using the `family:*` ARN pattern. |
| Deploy to ECS | One service, with conditions requiring the selected cluster and task family. |
| Check deployment progress | `DescribeServices` for that service. |
| Pass task roles | The two ECS execution/task roles, passed only to `ecs-tasks.amazonaws.com`. |
| Read build artifacts | `ListBucket` and `GetObject` for one artifacts bucket. |

Permissions left out:

- ECR deletion and repository administration: the pipeline only needs to push images.
- ECS cluster/service creation, standalone task execution and access to unrelated services: Terraform creates the infrastructure before CI releases an image.
- Arbitrary `PassRole`: CI only needs to pass the two roles used by this task definition.
- Task-definition tagging and `DescribeTaskDefinition`: CI registers an untagged definition and uses the ARN returned by registration.
- S3 writes/deletes, other buckets, IAM administration and role assumption: none are needed for the requested pipeline.

The ECS execution role has the image-download and log-writing permissions needed by running tasks. The service starts with zero tasks until the first image is available. CI then controls its task-definition revision and desired count; Terraform leaves those two fields alone on later runs.

## Task 5: Fix the cross-account role

The corrected configuration is in `terraform/modules/account-b/main.tf`. There are two separate problems in the original snippet.

### Wrong principal in the trust policy

`arn:aws:iam::000000000000:user/roleB` refers to an IAM user named roleB. The intended caller is a role, whose ARN contains `role/roleB`.

If that user does not exist, AWS can reject the trust policy. If it does exist, the policy trusts the wrong identity. The fix uses `var.role_b_arn`, passed from the actual roleB resource in Account A. RoleB also needs its own permission to call `sts:AssumeRole` on roleC.

### S3 access is too broad

`Action = "s3:*"` with `Resource = "*"` grants S3 access beyond the required bucket. The fix keeps `s3:*` but lists only the bucket ARN and its object ARN, `${bucket_arn}/*`. Both are needed because bucket actions and object actions use different resource ARNs.

The principal mistake prevents the intended role assumption. The S3 wildcard is a separate permissions problem that would remain after fixing the trust policy.

### Corrected code

The root passes roleB's ARN as `var.role_b_arn`. The bucket resource is declared in `storage.tf` in the same Account B module.

```hcl
locals {
  tags = {
    Environment = "assignment"
    Owner       = var.owner
  }
  account_b_bucket_arn = aws_s3_bucket.role_c.arn
}

resource "aws_iam_role" "role_c" {
  provider = aws

  name        = "roleC"
  description = "Full access to one Account B bucket; trusted only to Account A roleB."
  tags        = local.tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = var.role_b_arn }
    }]
  })
}

resource "aws_iam_role_policy" "role_c_permissions" {
  provider = aws

  name = "roleC-single-bucket-access"
  role = aws_iam_role.role_c.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:*"
      Resource = [local.account_b_bucket_arn, "${local.account_b_bucket_arn}/*"]
    }]
  })
}
```
