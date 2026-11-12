# Changelog

## 0.9.0 - Unreleased

- Move the MCP client bridge into core Connect with tools, resources, resource
  templates, prompts, completion, ping, status, notifications, and connection
  lifecycle support.
- Use ArborMCP `2.0.0-rc.6` for protocol and transports, including legacy notification
  listeners. Preserve endpoint fencing,
  credential leases, authorization, schema checks, notification scope, status
  deadlines, and host-owned client references.
- Use exact compatible Jido, Jido Action, Jido Signal, and Jido AI v3 Git
  revisions with ArborMCP `2.0.0-rc.6`.
- Add a catalog-backed Jido AI tool source for reviewed Connect Action packs.
- Standardize `CatalogPacks` across all providers with executable Actions,
  separate trigger and capability sets, and add a catalog-wide compatibility
  test.
- Block mutation packs from Jido AI tool loading until the host review and
  Connect prepare/commit authorization path is available.
- Make `Jido.Connect.Catalog.Item` the canonical catalog projection while the
  old tool paths remain narrow compatibility adapters.
- Upgrade generated Actions and catalog Actions to Jido Action v3 and remove
  the v2-only Action catalog projection.
- Remove the unused internal legacy descriptor builder and add direct coverage
  for the supported legacy lookup, search, and pack adapters.
- Remove the unpublished `jido_connect_mcp` application after its replacement
  tests and behavior moved into this package.
- Keep one nesting level more of `normalized_signal` in
  `WebhookDelivery.to_public_map/1`: signal values on level 4, such as the
  fields of an item in a list of the signal, stay instead of becoming
  `"[truncated]"`. `headers`, `payload` and `metadata` keep four levels. The
  512-byte and 50-entry limits and the redaction of sensitive keys apply on
  every level. The extra level applies to the signals of all providers: a
  GitHub push signal, for example, now shows the name and email of the author
  and committer of each commit and the `added`, `modified` and `removed` file
  lists, which a host that stores or logs the public map keeps too.

## 0.1.0

- Add the core `Jido.Connect` DSL, Zoi-backed contracts, generated Jido modules, and runtime adapters.
