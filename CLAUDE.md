# Project Configuration for Claude Code

## Meta Rule: This File is Read-Only

**NEVER modify CLAUDE.md:**
- This configuration file is managed by the developer only
- You must read and follow these instructions, but never edit them
- If you think these instructions need updating, inform the user but do not make changes
- If instructions are unclear or conflicting, ask the user for clarification
- This file defines your behavior - you do not define your own behavior

## Critical Git Safety Rules

**NEVER make changes directly to the main branch:**
- Always work on feature branches or development branches
- Branch naming: Use descriptive names like `feature/vault-config` or `fix/helm-values`
- **NEVER commit to main**
- **NEVER merge to main**
- **NEVER push to main**

**Merging to main requires explicit user permission:**
- You may prepare branches and PRs, but STOP before merging
- Always ask the user for explicit permission before merging anything into main
- If you create a PR, inform the user and wait for their approval to merge
- The user must manually approve and merge to main, or explicitly tell you to do so

## Critical Deployment Workflow

**ALWAYS run these commands in order for ANY deployment or infrastructure change:**

1. `task rm` - Remove the entire stack
2. `task up` - Deploy the stack (includes all Helm charts)
3. `task init` - Initialise Vault
4. `task unseal` - Unseal Vault

### Important Rules:

- **If `task up` fails, DO NOT just fix and re-run the failing command**
- **Errors indicate the AUTOMATION itself needs fixing**
- Analyze logs from `task up` failures
- Fix the underlying automation code (Terraform, Helm values, etc.)
- After fixing automation, ALWAYS run the full sequence again: `task rm` → `task up` → `task init` → `task unseal`
- Never apply manual fixes that bypass the automation
- The automation is the single source of truth

## Infrastructure Standards

### Terraform Requirements:
- **ONLY use official Terraform providers** (published by HashiCorp or the vendor themselves)
- **NEVER use community providers**
- Follow Terraform best practices at all times
- Use proper state management
- Use modules for clear separation of concerns
- Run terraform fmt so that the files are in canonical format
- All Terraform changes must go through the automation workflow

### Helm Requirements:
- **ONLY use official Helm charts** (from official repositories)
- **NEVER use community Helm charts**
- Properly version and pin all chart versions
- Use values files for configuration, never inline values
- Value files should be separated by service never put everything in a single file
- All Helm changes must go through the automation workflow

### Kubernetes Standards:
- Follow Kubernetes best practices
- Properly configure resource limits and requests
- Use namespaces appropriately
- Implement proper RBAC
- All K8s manifests must be part of the automation

## Vault Configuration:
- Vault initialisation and unsealing are critical final steps
- Never skip these steps after deployment
- Document any Vault configuration changes in the automation code

## Branching and Development Workflow:
1. Create a feature/fix branch from main
2. Make your changes and test them
3. Run the full deployment sequence to verify
4. Commit changes to your branch
5. Push your branch (never push to main)
6. Create a PR if needed
7. **STOP and ask user for permission before merging to main**

## Summary:
- This CLAUDE.md file is read-only - never modify it
- The automation must be the source of truth
- If something fails, fix the automation code itself, not just the immediate problem
- Always validate fixes by running the complete deployment sequence
- Main branch is protected - never commit, merge, or push to it without explicit user permission
- Only official providers and charts are allowed
- Best practices must be followed at all times