# Lab 7 migration record

On 2026-10-30, the three course stacks `successfulsuccess-auth`, `successfulsuccess-reports` and `successfulsuccess-ai` were migrated to HCP Terraform workspace `successfulsuccess-stashnid/successfulsuccess-dev` in account `312209831599`, region `us-east-1`. The workspace tracks `stashnid/SuccessfulSuccess`, branch `lab7-terraform`, with `infra/` as its working directory.

## Ownership transfer

- Every live CloudFormation-managed resource received `DeletionPolicy: Retain` and `UpdateReplacePolicy: Retain`. The SQS event source mapping and three Lambda URL/permission resources were detached separately with `PolicyAction: Retain`. The processed templates, parameters, outputs and physical IDs were backed up locally in the ignored `.lab7-backup/` directory, with the Google secret redacted.
- An HCP run triggered by GitHub imported **42 resources, 0 added, 0 changed, 0 destroyed**: [import run](https://app.terraform.io/app/successfulsuccess-stashnid/workspaces/successfulsuccess-dev/runs/run-VMVokKwGipbTS9Ty). [Apply finished screenshot](evidence/lab7-hcp-apply-finished.png).
- The three CloudFormation stacks reached `DELETE_COMPLETE`. Retained Cognito, S3, SQS, Lambda, Scheduler, SNS and related resources were checked afterward. The follow-up [plan-only run](https://app.terraform.io/app/successfulsuccess-stashnid/workspaces/successfulsuccess-dev/runs/run-H4E276tVrRnDE2BZ) showed **No changes; 0 to add, 0 to change, 0 to destroy**. [Plan screenshot](evidence/lab7-no-changes.png).
- After this check, the one-time import blocks, old three YAML templates and their CloudFormation Guard files were removed. The other CloudFormation templates for frontend, ECR and the unused backend design are outside this lab's migration.

## Safety and operating notes

- The Cognito user pool and reports bucket have Terraform `prevent_destroy` guards. The Google OAuth secret is a sensitive HCP variable, not a committed file. State is remote in HCP; its access must remain restricted.
- HCP uses an OIDC role limited to this workspace. It has read access and may change tags only on the `successfulsuccess-agenda-parser` Lambda. All other write access requires a separately reviewed, scoped policy update.
- The current website/API still use CloudFront, ECS and PostgreSQL. Lab 7 migrated the authentication, weekly reports and agenda parser infrastructure only. AWS Free plan and the existing resource choices were unchanged.
- Application deployment is a separate, manual GitHub Actions workflow. Infrastructure changes should be reviewed and applied in HCP first, followed by application deployment when it depends on those changes.
- The migration used **42 imports and 0 re-creations**. There was no replacement of user accounts or report objects.

## Drift exercise

- A temporary `LAB7_DRIFT=temporary-check` tag was added to the agenda parser Lambda outside Terraform. [The plan-only run](https://app.terraform.io/app/successfulsuccess-stashnid/workspaces/successfulsuccess-dev/runs/run-JvXSVTyM21qocEBP) detected only its removal: **0 to add, 1 to change, 0 to destroy**. [Drift plan screenshot](evidence/lab7-drift-detected.png).
- After reviewing that plan, [the HCP apply](https://app.terraform.io/app/successfulsuccess-stashnid/workspaces/successfulsuccess-dev/runs/run-1Mwpje3odrwHdKk7) removed the temporary tag: **0 added, 1 changed, 0 destroyed**. AWS `ListTags` confirmed that `LAB7_DRIFT` is absent. [Apply screenshot](evidence/lab7-drift-restored.png).
- The subsequent [plan-only check](https://app.terraform.io/app/successfulsuccess-stashnid/workspaces/successfulsuccess-dev/runs/run-U2NLmQjRVF8tQCLZ) finished with **No changes; 0 to add, 0 to change, 0 to destroy**. [Final plan screenshot](evidence/lab7-final-no-changes.png).
- If a manual change were an urgent production fix, the team would put the desired setting in Terraform, review the plan, and apply that change so it survives future runs.
