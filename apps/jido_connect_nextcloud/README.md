# jido_connect_nextcloud

Nextcloud connector package for Jido Connect.

This package keeps Nextcloud as one connector while splitting internals by
capability. It currently covers Files, OCS sharing, capability discovery, and a
minimal Nextcloud Office external-app launch-token helper.

## Installation

```elixir
def deps do
  [
    {:jido_connect_nextcloud, in_umbrella: true}
  ]
end
```

## Auth

The recommended profile is `:app_password`. Store:

- `:base_url` - the Nextcloud instance root, for example `https://cloud.example.com`
- `:login_name` - the login name returned by Nextcloud login flow or entered by the user
- `:app_password` - a Nextcloud app password

The package also declares an `:oauth2_user` profile for hosts that explicitly
want Nextcloud OAuth2. Nextcloud's built-in OAuth2 tokens are not scoped by
resource, so hosts should treat them as broad account access.

## Actions

### Files

| Action ID | Description | Confirmation |
|---|---|---|
| `nextcloud.files.list` | List children under a folder path using WebDAV PROPFIND | none |
| `nextcloud.file.get` | Fetch WebDAV metadata for one file/folder | none |
| `nextcloud.files.search` | Search files using WebDAV SEARCH | none |
| `nextcloud.file.download` | Download file content | none |
| `nextcloud.folder.create` | Create a folder with MKCOL | required_for_ai |
| `nextcloud.file.upload` | Upload or replace file content | required_for_ai |
| `nextcloud.node.move` | Move or rename a file/folder | required_for_ai |
| `nextcloud.node.copy` | Copy a file/folder | required_for_ai |
| `nextcloud.node.delete` | Delete a file/folder | always |

### Shares

| Action ID | Description | Confirmation |
|---|---|---|
| `nextcloud.shares.list` | List shares or shares for one path | none |
| `nextcloud.share.get` | Get one share by id | none |
| `nextcloud.share.create` | Create a user, group, email, federated, Talk, or public-link share | always |
| `nextcloud.share.update` | Update share permissions or metadata | always |
| `nextcloud.share.delete` | Delete a share | always |
| `nextcloud.sharees.search` | Search share recipients | none |

### Office

| Action ID | Description | Confirmation |
|---|---|---|
| `nextcloud.office.capabilities.get` | Read Nextcloud capabilities and derive Office availability | none |
| `nextcloud.office.launch_token.get` | Fetch richdocuments external-app launch data for a file id | always |

Office collaborative editing remains host/browser-owned. This connector only
returns launch metadata when a Nextcloud instance has explicitly enabled
external-app access in the richdocuments app.

## Catalog Packs

- `:nextcloud_files_readonly`
- `:nextcloud_files_write`
- `:nextcloud_files_destructive`
- `:nextcloud_sharing`
- `:nextcloud_office`
- `:nextcloud_full`

## Live Smoke Tests

Offline tests are the default. Read-oriented live smoke tests can be run with:

```sh
NEXTCLOUD_BASE_URL="https://cloud.example.com" \
NEXTCLOUD_LOGIN_NAME="alice" \
NEXTCLOUD_APP_PASSWORD="..." \
  mix test test/jido_connect/nextcloud/live_smoke_test.exs --include live_smoke
```

Write and destructive live checks should be added behind explicit opt-in env
flags once a disposable Nextcloud account is available.
