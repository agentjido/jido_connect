# Google Connector Conventions

Google product packages use the same public contract shape so hosts can expose
Gmail, Sheets, Drive, Calendar, and later Google products consistently.

## Tool IDs

Action and trigger IDs use dot-separated lowercase segments:

```text
google.<product>.<resource>.<verb>
```

Examples:

- `google.gmail.message.get`
- `google.sheets.values.update`
- `google.drive.file.changed`
- `google.calendar.event.delete`

Use the public Google product name segment, not the Hex package suffix:
`gmail`, `sheets`, `drive`, `calendar`, `contacts`, `meet`, and so on.

## Generated Modules

Generated Jido modules stay under the product namespace:

- Actions: `<ProductNamespace>.Actions.<ActionName>`
- Sensors: `<ProductNamespace>.Sensors.<SensorName>`
- Plugin: `<ProductNamespace>.Plugin`

Sensor module names expose the trigger ID directly:

- `name/0` is the trigger ID with dots replaced by underscores.
- `trigger_id/0` is the canonical trigger ID.
- `signal_type/0` equals the canonical trigger ID.

## Catalog Packs

Pack IDs use `google_<product>_<surface>` atoms, for example
`:google_gmail_metadata` or `:google_drive_file_writer`.

Each built-in pack must:

- filter to the integration provider ID;
- list only action or trigger IDs exposed by that integration;
- carry `metadata.package` with the package atom;
- carry either `metadata.risk` for broad surfaces or `metadata.excludes` for
  curated packs that intentionally omit riskier tools;
- use non-empty labels and descriptions.

## Classification And Risk

Every action and trigger declares `data_classification` from
`Jido.Connect.Taxonomy.data_classifications/0`.

Every action declares risk and confirmation metadata from
`Jido.Connect.Taxonomy`:

- non-mutating actions use `:metadata` or `:read`;
- mutating actions use `:write`, `:external_write`, or `:destructive`;
- `:external_write` actions require confirmation;
- `:destructive` actions require `confirmation: :always`.

## Future Product Checklist

When adding another Google product package:

1. Add its action IDs with the `google.<product>.` prefix.
2. Keep generated modules under the product namespace.
3. Add catalog pack delegates and `google_<product>_` pack IDs.
4. Declare labels, data classifications, risks, confirmations, and scope
   resolvers before adding handler tests.
5. Reuse `Jido.Connect.Google.TestSupport.ConnectorContracts` in the package
   tests to enforce this contract offline.
6. Follow [Extension Patterns](extension_patterns.md) for client, handler,
   normalization, scope, catalog, trigger, and checkpoint placement.
