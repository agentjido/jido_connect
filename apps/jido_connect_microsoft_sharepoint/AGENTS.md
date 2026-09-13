# Microsoft SharePoint Connector Guidance

- Reuse Microsoft auth, transport, pagination, scope, and checkpoint helpers.
- Reuse Microsoft OneDrive structs and handlers for SharePoint document libraries.
- Keep site, list, list-item, document-library, and trigger code in separate groups.
- Keep selected-resource grant storage and checkpoint storage in the host.
- Do not log list field values, file content, access tokens, client secrets, or delta links.
- Normalize all Graph payloads before returning them from an action handler.
