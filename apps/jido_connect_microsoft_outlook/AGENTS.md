# Microsoft Outlook Connector Guidance

- Reuse auth profiles, transport, pagination, scopes, account, and checkpoint
  helpers from the shared `jido_connect_microsoft` foundation package. Do not
  duplicate OAuth or Graph transport logic here.
- Keep action handlers small and grouped by capability (read, send, draft,
  label, folder). Avoid catch-all client modules.
- Use `Jido.Connect.Microsoft.Scopes` for Microsoft Graph mail scope
  normalization and encode. Use the Outlook scope resolver for dynamic
  least-privilege resolution.
- Use `Jido.Connect.Microsoft.Checkpoint` for poll-trigger checkpoint errors.
- Do not log or expose access tokens, refresh tokens, or raw credential leases.
- Normalize Graph mail payloads through dedicated Outlook structs once they are
  introduced.
- Handlers in the initial scaffold return `{:error, :not_implemented}`. Replace
  with real Graph calls in follow-up tasks.
