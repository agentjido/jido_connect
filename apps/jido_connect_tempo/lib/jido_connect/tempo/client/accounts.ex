defmodule Jido.Connect.Tempo.Client.Accounts do
  @moduledoc """
  Tempo account candidates of a Jira project.

  `list_for_project/3` reads
  `GET /4/account-links/project/{projectId}?includeGlobalAccounts=true`
  once, then `GET /4/accounts/{id}` once per account that a link of the
  project names, in link order. The answer is not paginated.

  Each link must carry an integer `id` of at least 0, a boolean `default`,
  a `scope` with a non-empty `type` and an integer `id`, and an
  `account.self` reference. The account ID comes from that reference only
  after it passed two checks: it must name a Tempo origin under the rule of
  `Jido.Connect.Tempo.Client.Request.tempo_link?/2`, so the `https://api.tempo.io`
  links of a regional site are accepted, and its path must be exactly
  `/4/accounts/{id}` with a positive decimal ID, without query or fragment.
  The reference is never requested: the details are read at the
  connection's origin. Every link is checked before the first account
  read.

  A link is a candidate when its scope is `PROJECT` with the requested
  project ID. A link of another project or scope type is left out, and its
  account is read only when another link makes it a candidate. Links that
  name the same account are kept together on that account.

  The read succeeds only as a whole. These failures are
  `Jido.Connect.Error.ProviderError`s with `delivery: :response_received`:

  | Reason | Cause | Details |
  | --- | --- | --- |
  | `:invalid_account_links` | an answer without a `results` list | |
  | `:invalid_account_link` | a missing or malformed link field | `index`, `field` |
  | `:foreign_account_reference` | an `account.self` on another origin or path | `index`, `link_id` |
  | `:account_limit_exceeded` | more candidate accounts than `:max_accounts`, before the first account read | `max_accounts`, `accounts` |
  | `:invalid_account` | details that do not normalize with `Jido.Connect.Tempo.Account.normalize/2` | `account_id`, `field` |
  | `:account_mismatch` | details of another account than the requested one | `account_id`, `returned_id` |

  A failed account read, such as Tempo's 404 `Invalid account` or a 403,
  fails the read with its normalized error; no candidate is returned
  without its details. No detail holds a reference URL.
  """

  alias Jido.Connect.Error
  alias Jido.Connect.Tempo.Account
  alias Jido.Connect.Tempo.Client.{Request, Response, Transport}

  @defaults [max_accounts: 100]
  @account_path ~r{\A/4/accounts/([1-9][0-9]*)\z}

  @doc "Returns the default bound."
  @spec defaults() :: keyword(pos_integer())
  def defaults, do: @defaults

  @doc """
  Reads the account candidates of the Jira project `project_id`.

  `project_id` is a positive integer; anything else is a
  `Jido.Connect.Error.ValidationError` with reason `:invalid_project_id`
  before any request. The option `:max_accounts` (default 100) bounds the
  account reads; an invalid value is a `ValidationError` with reason
  `:invalid_account_option`.

  Returns the accounts in the order of their first candidate link.
  """
  @spec list_for_project(Request.t(), pos_integer(), keyword()) ::
          {:ok, [Account.t()]} | {:error, Error.ProviderError.t() | Error.ValidationError.t()}
  def list_for_project(%Request{} = request, project_id, opts \\ []) when is_list(opts) do
    with :ok <- check_project_id(project_id),
         {:ok, max_accounts} <- max_accounts(opts),
         {:ok, body} <-
           Transport.get(request, "/4/account-links/project/#{project_id}",
             params: [includeGlobalAccounts: true]
           ),
         {:ok, links} <- links(body),
         candidates = Enum.filter(links, &candidate?(&1, project_id)),
         ids = candidates |> Enum.map(& &1.account_id) |> Enum.uniq(),
         :ok <- check_bound(ids, max_accounts) do
      read_accounts(request, ids, candidates)
    end
  end

  defp check_project_id(project_id) when is_integer(project_id) and project_id > 0, do: :ok

  defp check_project_id(_project_id) do
    {:error,
     Error.validation("Tempo project ID must be a positive integer",
       reason: :invalid_project_id,
       subject: :project_id
     )}
  end

  defp max_accounts(opts) do
    case Keyword.get(opts, :max_accounts, @defaults[:max_accounts]) do
      value when is_integer(value) and value > 0 ->
        {:ok, value}

      _other ->
        {:error,
         Error.validation("Invalid Tempo account option",
           reason: :invalid_account_option,
           subject: :max_accounts,
           details: %{option: :max_accounts, message: "must be a positive integer"}
         )}
    end
  end

  defp links(%{"results" => results}) when is_list(results) do
    results
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {link, index}, {:ok, links} ->
      case link(link, index) do
        {:ok, link} -> {:cont, {:ok, [link | links]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, links} -> {:ok, Enum.reverse(links)}
      error -> error
    end
  end

  defp links(_body), do: error(:invalid_account_links, "Tempo account links were invalid", %{})

  defp link(%{} = link, index) do
    with {:ok, id} <- field(link, ["id"], &(is_integer(&1) and &1 >= 0), index),
         {:ok, default} <- field(link, ["default"], &is_boolean/1, index),
         {:ok, scope_type} <- field(link, ["scope", "type"], &non_empty_string?/1, index),
         {:ok, scope_id} <- field(link, ["scope", "id"], &is_integer/1, index),
         {:ok, self} <- field(link, ["account", "self"], &is_binary/1, index),
         {:ok, account_id} <- account_id(self, index, id) do
      {:ok,
       %{
         account_id: account_id,
         evidence: %{id: id, default: default, scope_type: scope_type, scope_id: scope_id}
       }}
    end
  end

  defp link(_link, index), do: invalid_link(index, "link")

  defp field(link, path, valid?, index) do
    value = fetch(link, path)
    if valid?.(value), do: {:ok, value}, else: invalid_link(index, Enum.join(path, "."))
  end

  defp fetch(value, []), do: value
  defp fetch(map, [key | rest]) when is_map(map), do: fetch(Map.get(map, key), rest)
  defp fetch(_value, _path), do: nil

  defp non_empty_string?(value), do: is_binary(value) and value != ""

  # The reference must name a Tempo origin and exactly /4/accounts/{id}; it
  # is only parsed, never requested.
  defp account_id(self, index, link_id) do
    uri = URI.parse(self)

    with true <- is_nil(uri.query) and is_nil(uri.fragment),
         [_path, id] <- Regex.run(@account_path, uri.path || ""),
         true <- Request.tempo_link?(self, uri.path) do
      {:ok, String.to_integer(id)}
    else
      _other ->
        error(
          :foreign_account_reference,
          "Tempo account link names another origin or path",
          %{index: index, link_id: link_id}
        )
    end
  end

  defp candidate?(%{evidence: evidence}, project_id),
    do: evidence.scope_type == "PROJECT" and evidence.scope_id == project_id

  defp check_bound(ids, max_accounts) when length(ids) <= max_accounts, do: :ok

  defp check_bound(ids, max_accounts) do
    error(:account_limit_exceeded, "Tempo project has more candidate accounts than the limit", %{
      max_accounts: max_accounts,
      accounts: length(ids)
    })
  end

  defp read_accounts(request, ids, candidates) do
    evidence = Enum.group_by(candidates, & &1.account_id, & &1.evidence)

    ids
    |> Enum.reduce_while({:ok, []}, fn id, {:ok, accounts} ->
      case read_account(request, id, Map.fetch!(evidence, id)) do
        {:ok, account} -> {:cont, {:ok, [account | accounts]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, accounts} -> {:ok, Enum.reverse(accounts)}
      error -> error
    end
  end

  defp read_account(request, id, links) do
    with {:ok, body} <- Transport.get(request, "/4/accounts/#{id}"),
         {:ok, account} <- normalize(body, links, id) do
      if account.id == id do
        {:ok, account}
      else
        error(:account_mismatch, "Tempo returned the details of another account", %{
          account_id: id,
          returned_id: account.id
        })
      end
    end
  end

  defp normalize(body, links, id) do
    case Account.normalize(body, links) do
      {:ok, account} ->
        {:ok, account}

      {:error, field} ->
        error(:invalid_account, "Tempo account was invalid", %{account_id: id, field: field})
    end
  end

  defp invalid_link(index, field),
    do:
      error(:invalid_account_link, "Tempo account link was invalid", %{index: index, field: field})

  defp error(reason, message, details),
    do: Response.invalid_response(message, nil, reason: reason, details: details)
end
