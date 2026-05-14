# Jido Connect Google Contacts

Google Contacts provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps People API-specific DSL,
handlers, schemas, normalized structs, and tests in this package.

## Status

This package declares the Contacts provider, OAuth profile, Contacts scope
resolver, normalized person/contact group structs, People API read, batch,
directory, other-contact, group lifecycle/member, mutation actions, poll
trigger metadata, and curated catalog packs.

## Actions

- `google.contacts.person.list`
- `google.contacts.person.get`
- `google.contacts.person.search`
- `google.contacts.person.batch_get`
- `google.contacts.person.batch_create`
- `google.contacts.person.batch_update`
- `google.contacts.person.batch_delete`
- `google.contacts.directory.list`
- `google.contacts.directory.search`
- `google.contacts.other.list`
- `google.contacts.other.search`
- `google.contacts.other.copy`
- `google.contacts.group.get`
- `google.contacts.group.batch_get`
- `google.contacts.group.delete`
- `google.contacts.group.member.modify`
- `google.contacts.person.create`
- `google.contacts.person.update`
- `google.contacts.person.delete`
- `google.contacts.group.list`
- `google.contacts.group.create`
- `google.contacts.group.update`

## Catalog Packs

- `:google_contacts_readonly` includes person reads, person search, batch get,
  directory reads, other-contact reads, and contact group list/get/batch-get
  without mutation tools.
- `:google_contacts_manager` includes the full Contacts surface: read tools,
  batch contact create/update/delete, other-contact copy, contact
  create/update/delete, and contact group create/update/delete/member modify.

## Triggers

- `google.contacts.person.changed` polls `people.connections.list` with sync
  tokens and emits normalized changed contact signals. The initial poll captures
  the sync checkpoint without replaying historical contacts.

```elixir
Jido.Connect.Catalog.search_tools("contacts",
  modules: [Jido.Connect.Google.Contacts],
  packs: Jido.Connect.Google.Contacts.catalog_packs(),
  pack: :google_contacts_manager
)
```

## Scopes

The connector starts with the narrow Contacts scopes from the shared Google
scope catalog:

- `contacts.readonly` for contact reads and search.
- `contacts` for contact and contact group mutations.
- `contacts.other.readonly` for other-contact list/search and, where Google
  allows it, copying an other contact into myContacts.
- `directory.readonly` for domain directory list/search.
