# Atlassian Shared Package Guidance

- Keep this package limited to Atlassian concerns that Jira and Confluence
  share, such as the Atlassian Document Format. Product endpoints, DSL
  declarations, auth and transport stay in the product packages.
- This package is library-only. Do not add a provider registration, an
  application supervisor or HTTP calls.
- Keep modules small and grouped by capability under
  `Jido.Connect.Atlassian.*`.
- Return `Jido.Connect.Error` structs for normalized errors. Error details name
  node types and limits only; they never carry document text.
- ADF test fixtures come from Atlassian's document format reference and cite
  the page they come from.
