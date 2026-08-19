# Atlassian, Trello, and X action contracts

This document records the reviewed provider actions used by hosts such as
Wayfinder. Provider packages own the canonical action IDs. Hosts select exact
IDs through reviewed catalog packs and must not publish a generic MCP tool
caller.

The former Ando domain IDs are migration references only. New catalog entries
use provider IDs and do not keep the former IDs as aliases.

## Transport and identity

| Provider | Transport | Connection identity |
| --- | --- | --- |
| Jira | Jira Cloud REST API v3 and Jira Software REST API | HTTPS site plus Atlassian account |
| Confluence | Confluence Cloud REST API v2 | HTTPS site plus Atlassian account |
| Bitbucket | Bitbucket Cloud REST API v2 | Workspace and repository plus Atlassian account |
| Trello | Hosted Trello MCP at `https://mcp.trello.com/v1` | One authorized workspace and one reviewed board binding |
| X | Official local XMCP server | Authenticated X account and expected username |

Jira, Confluence, and Bitbucket have separate provider identities even when a
host uses related Atlassian credentials. Trello and X use typed provider
actions over `jido_connect_mcp`; their public packs never include
`mcp.tools.list`, `mcp.tools.call`, or `mcp.tool.call`.

## Jira

The Jira package keeps its current ten actions and adds these nineteen
canonical actions:

| Canonical action | Former Ando action | Effect |
| --- | --- | --- |
| `jira.board.list` | `issues.board.list` | read |
| `jira.board.get` | `issues.board.get` | read |
| `jira.board.create` | `issues.board.create` | write |
| `jira.filter.list` | `issues.filter.list` | read |
| `jira.filter.get` | `issues.filter.get` | read |
| `jira.filter.create` | `issues.filter.create` | write |
| `jira.filter.update` | `issues.filter.update` | write |
| `jira.filter.columns.get` | `issues.filter.columns.get` | read |
| `jira.filter.columns.update` | `issues.filter.columns.update` | write |
| `jira.filter.share.update` | `issues.filter.share.update` | external write |
| `jira.issue.transition.list` | `issues.issue.transition.list` | read |
| `jira.issue.delete` | `issues.issue.delete` | destructive write |
| `jira.plan.list` | `issues.plan.list` | privileged read |
| `jira.plan.get` | `issues.plan.get` | privileged read |
| `jira.plan.create` | `issues.plan.create` | privileged write |
| `jira.plan.update` | `issues.plan.update` | privileged write |
| `jira.plan.duplicate` | `issues.plan.duplicate` | privileged write |
| `jira.plan.archive` | `issues.plan.archive` | destructive write |
| `jira.plan.trash` | `issues.plan.trash` | destructive write |

Board paging uses `offset` and `limit`. Filter paging uses `offset` and
`limit`. Plan paging uses a cursor. All limits are bounded to 100. Filter share
replacement is a multi-request write and must not be retried automatically.
Plan actions require a host policy for Jira administration access.

## Bitbucket

`bitbucket.pull_request.list` replaces
`repositories.pull-request.list`. It reads
`GET /repositories/{workspace}/{repository}/pullrequests` with a state,
page length of at most 50, and a positive page number. Results contain only the
pull request ID, title, state, source and destination branches, author summary,
draft state, timestamps, and web URL.

## Confluence

| Canonical action | Former Ando action | Effect |
| --- | --- | --- |
| `confluence.space.get` | `wiki.space.get` | read |
| `confluence.page.list` | `wiki.page.list` | read |
| `confluence.page.get` | `wiki.page.get` | read |
| `confluence.page.create` | `wiki.page.create` | write |
| `confluence.page.update` | `wiki.page.update` | write |
| `confluence.page.delete` | `wiki.page.delete` | destructive write |

Page updates first read the remote page. The handler verifies its space and
version before it sends the next version. A forced update can bypass version
equality, but it cannot bypass the space check. Page reads limit returned text
to 100,000 characters.

## Trello

The Trello package binds one reviewed action to each fixed MCP tool and action
value:

| Canonical action | MCP tool and action | Effect |
| --- | --- | --- |
| `trello.board.get` | `trelloReadBoard:get` | read |
| `trello.list.list` | `trelloReadList:list_by_board` | read |
| `trello.list.get` | `trelloReadList:get` | read |
| `trello.list.create` | `trelloWriteList:create` | write |
| `trello.list.update` | `trelloWriteList:update` | write |
| `trello.list.move` | `trelloWriteList:move` | write |
| `trello.list.archive` | `trelloWriteList:archive` | destructive write |
| `trello.label.list` | `trelloReadBoard:list_labels` | read |
| `trello.card.list` | `trelloReadCard:list_by_board` or `list_by_list` | read |
| `trello.card.get` | `trelloReadCard:get` | read |
| `trello.card.search` | `trelloSearch:search_cards` | read |
| `trello.card.create` | `trelloWriteCard:create` | write |
| `trello.card.update` | `trelloWriteCard:update` | write |
| `trello.card.move` | `trelloWriteCard:move` | write |
| `trello.card.complete` | `trelloWriteCard:mark_done` | write |
| `trello.card.archive` | `trelloWriteCard:archive` | destructive write |
| `trello.card.label.attach` | `trelloWriteCard:attach_label` | write |
| `trello.card.label.detach` | `trelloWriteCard:detach_label` | write |
| `trello.checklist.list` | `trelloReadChecklist:list_by_card` | read |
| `trello.checklist.create` | `trelloWriteChecklist:create` | write |
| `trello.checklist.update` | `trelloWriteChecklist:update` | write |
| `trello.checklist.item.create` | `trelloWriteChecklist:add_item` | write |
| `trello.checklist.item.update` | `trelloWriteChecklist:update_item` | write |

The host supplies the selected workspace and board identity. Callers cannot
replace the endpoint, workspace, board, remote tool, or remote action.

## X

| Canonical action | XMCP tool | Effect |
| --- | --- | --- |
| `x.account.get` | `get_users_me` | read |
| `x.bookmark.list` | `get_users_bookmarks` | read |
| `x.post.list` | `get_users_posts` | read |

The connector calls `get_users_me` first and compares the returned username
with the connection identity. It injects the returned account ID into bookmark
and post calls. The approved XMCP allow-list contains only these three tools.

## Primary references

- Jira Cloud REST API v3:
  <https://developer.atlassian.com/cloud/jira/platform/rest/v3/>
- Jira Software board API:
  <https://developer.atlassian.com/cloud/jira/software/rest/api-group-board/>
- Confluence Cloud REST API v2:
  <https://developer.atlassian.com/cloud/confluence/rest/v2/>
- Bitbucket pull request API:
  <https://developer.atlassian.com/cloud/bitbucket/rest/api-group-pullrequests/>
- Trello MCP:
  <https://support.atlassian.com/trello/docs/connect-trello-to-ai-assistants-with-trello-mcp/>
- X MCP servers:
  <https://docs.x.com/tools/mcp>
