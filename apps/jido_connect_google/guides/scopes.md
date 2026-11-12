# Google Scopes

The Google connector family treats OAuth scope coverage as action metadata, not
host-app convention.

Every Google action must declare:

- Static `scopes` metadata in its DSL `access` block. This is the
  least-privilege scope advertised through the action catalog.
- A provider-local `scope_resolver`. This is the dynamic runtime contract for
  cases where a broader already-granted scope can satisfy a narrower action, or
  where Google requires a broader scope for a specific endpoint.
- Auth profile coverage. Every static or resolved scope must be listed in the
  provider's `default_scopes` or `optional_scopes`.

The shared test contract
`Jido.Connect.Google.TestSupport.ConnectorContracts.assert_google_naming_and_catalog_conventions/2`
enforces this for each Google provider metadata test. It checks every action in
`provider.integration().actions`, and it checks trigger scope resolvers where a
provider has triggers.

## Verification

Each Google provider has a local scope resolver. The shared connector contract
checks static scopes and dynamic resolver coverage without a network call.

## Adding Google Actions

When adding a Google action:

1. Add `scopes([...], resolver: Product.ScopeResolver)` in the action's
   `access` block.
2. Add the operation id to the product resolver when the default resolver logic
   is not sufficient.
3. Add the scope to the provider OAuth profile's optional scopes when it is new
   to the package.
4. Add or extend the product scope resolver test for the new branch.
5. Keep the action in a catalog pack whose risk and exclusions match the scope
   behavior.

Do not move provider-specific scope translation into `jido_connect` core. The
core runtime validates the metadata; each provider package owns its API-specific
least-privilege choices.
