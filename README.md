# m365-endpoint-automation
A collection of PowerShell scripts focused on Microsoft 365 administration, endpoint management, remediation scenarios, automation and security.

## Purpose
This repository demonstrates:
- automation of repetitive IT administration tasks
- endpoint management using Microsoft Intune
- reporting and visibility scripts for users and devices
- security-aware administration practices

## Technologies
- PowerShell
- Microsoft Intune
- Microsoft Entra ID
- Microsoft Graph API
- Microsoft 365

## Structure
scripts/
  user-lifecycle/
  reporting/
  intune/
  entra/
templates/
modules/
docs/
examples/

## Example Use Cases
- user onboarding and offboarding
- inactive users reporting
- device compliance reporting
- detection and remediation of outdated software
- general Microsoft 365 reporting

## Notes
- no credentials or secrets are stored in this repository
- scripts are intended for demo and learning purposes
- scripts should be tested before use in production environments

## Example Scripts
- inactive-users-report.ps1
- device-compliance-report.ps1
- detect-outdated-7zip.ps1
- remediate-outdated-7zip.ps1
- users-without-mfa.ps1
- risky-users-report.ps1
- autopilot-enrollment.ps1
## Author
Metodi Todorinov
