# Microsoft Foundation Guidance

- Keep this package provider-neutral for Microsoft Graph product connectors. Shared auth,
  account metadata, transport, error, pagination, and scope helpers belong here;
  Outlook, Calendar, OneDrive, and other product endpoint logic does not.
- Keep modules small and grouped by contract: account/profile structs,
  connections, OAuth, scopes, transport, pagination, and provider error mapping.
- This package is library-only. Do not add an application supervisor unless the
  package owns long-lived processes.
- Public helpers should be storage-free. Hosts own durable credential storage,
  connection persistence, OAuth callback state, and checkpoint persistence.
