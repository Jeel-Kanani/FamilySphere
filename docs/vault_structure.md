# Vault Structure

## Overview
The Vault is organized into 3 top-level tiers:

1. `Shared`
2. `Personal`
3. `Private`

Each tier supports:
- Built-in folder structure
- User-created custom folders

## Tier 1: Shared

`Shared` is for family-level documents and member-wise identity/education/work records.

### Shared Root (line-by-line)
- `Individual` (member-wise subtree)
- `Property Deed`
- `Medical`
- `Insurance`
- `Vehicle`
- `Finance & Tax`
- `Legal`
- `Education`
- `Household Bills`
- `Family Identity`
- `+ Custom folders`

### Shared > Individual > Member-wise

Example:
- `Individual`
  - `Jeel`
  - `Meet`
  - `Kavy`
  - `...other family members`

Inside each member:
- `Aadhaar Card`
- `PAN Card`
- `Passport`
- `Voter ID`
- `Driving License`
- `Birth Certificate`
- `10th Marksheet`
- `12th Marksheet`
- `Results`
- `Degree/Certificates`
- `Bank/KYC`
- `Employment`
- `+ Custom folders`

## Tier 2: Personal

`Personal` is for the current user’s own non-family documents.

Built-in folders:
- `Study & Learning`
- `Career Documents`
- `Business`
- `Portfolio`
- `Personal Certificates`
- `Creative Work`
- `Travel`
- `Misc Personal`
- `+ Custom folders`

## Tier 3: Private

`Private` is for highly sensitive personal documents/credentials.

Built-in folders:
- `Passwords`
- `Confidential Notes`
- `Legal Contracts`
- `Bank Accounts`
- `Identity Secrets`
- `Recovery Keys`
- `Private Finance`
- `Critical Credentials`
- `+ Custom folders`

## Data Model Notes

Documents are stored with:
- `category` (`Shared | Personal | Private`)
- `folder`
- `memberId` (optional; used for member-wise grouping in `Shared`)

Folders are stored with:
- `familyId`
- `category`
- `memberId` (optional)
- `name`
- `isSystem`

## Backward Compatibility

Legacy documents with category `Individual` are treated as `Shared` in read queries.
