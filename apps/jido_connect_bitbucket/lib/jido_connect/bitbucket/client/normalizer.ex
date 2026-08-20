defmodule Jido.Connect.Bitbucket.Client.Normalizer do
  @moduledoc "Strict Bitbucket pull-request response normalization."

  alias Jido.Connect.Data
  alias Jido.Connect.Bitbucket.PullRequestContract, as: Contract

  @states Contract.states()
  @response_states Contract.response_states()
  @minimum_limit Contract.minimum_limit()
  @maximum_limit Contract.maximum_limit()
  @minimum_page Contract.default_page()
  @maximum_page Contract.maximum_page()

  @doc "Normalizes a paginated pull-request response or returns `:error`."
  @spec normalize_list(map(), map()) :: {:ok, map()} | :error
  def normalize_list(body, context) when is_map(body) and is_map(context) do
    values = Data.get(body, "values")
    total = Data.get(body, "size")
    page = Data.get(body, "page")
    page_length = Data.get(body, "pagelen")
    next_page = Data.get(body, "next")

    with true <- is_list(values),
         true <- valid_context?(context),
         true <- valid_integer?(total, 0, :infinity),
         true <- valid_integer?(page, @minimum_page, @maximum_page),
         true <- page == context.page,
         true <- valid_integer?(page_length, @minimum_limit, @maximum_limit),
         true <- page_length == context.limit,
         true <- length(values) <= page_length,
         true <- total >= length(values),
         {:ok, next_page} <- optional_https_url(next_page),
         {:ok, items} <- normalize_items(values) do
      {:ok,
       %{
         kind: "pull_requests",
         account: context.account,
         workspace: context.workspace,
         repository: context.repository,
         state: context.state,
         count: length(items),
         page: page,
         page_length: page_length,
         total: total,
         next_page: next_page,
         items: items
       }}
    else
      _invalid -> :error
    end
  end

  def normalize_list(_body, _context), do: :error

  defp normalize_items(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, items} ->
      case normalize_item(value) do
        {:ok, item} -> {:cont, {:ok, [item | items]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      :error -> :error
    end
  end

  defp normalize_item(item) when is_map(item) do
    id = Data.get(item, "id")
    title = Data.get(item, "title")
    state = Data.get(item, "state")
    source_branch = item |> Data.get("source") |> branch_name()
    destination_branch = item |> Data.get("destination") |> branch_name()
    author = Data.get(item, "author")
    author_id = author_id(author)
    author_display_name = if is_map(author), do: Data.get(author, "display_name")
    draft = Data.get(item, "draft")
    created_at = Data.get(item, "created_on")
    updated_at = Data.get(item, "updated_on")
    url = item |> Data.get("links") |> html_url()

    with true <- valid_integer?(id, 1, :infinity),
         true <- non_empty_string?(title),
         true <- state in @response_states,
         true <- non_empty_string?(source_branch),
         true <- non_empty_string?(destination_branch),
         true <- non_empty_string?(author_id),
         true <- non_empty_string?(author_display_name),
         true <- is_boolean(draft),
         true <- iso8601?(created_at),
         true <- iso8601?(updated_at),
         {:ok, url} <- https_url(url) do
      {:ok,
       %{
         id: id,
         title: title,
         state: String.downcase(state),
         source_branch: source_branch,
         destination_branch: destination_branch,
         author: %{id: author_id, display_name: author_display_name},
         draft: draft,
         created_at: created_at,
         updated_at: updated_at,
         url: url
       }}
    else
      _invalid -> :error
    end
  end

  defp normalize_item(_item), do: :error

  defp valid_context?(context) do
    non_empty_string?(Map.get(context, :account)) and
      non_empty_string?(Map.get(context, :workspace)) and
      non_empty_string?(Map.get(context, :repository)) and
      Map.get(context, :state) in @states and
      valid_integer?(Map.get(context, :limit), @minimum_limit, @maximum_limit) and
      valid_integer?(Map.get(context, :page), @minimum_page, @maximum_page)
  end

  defp branch_name(ref) when is_map(ref) do
    case Data.get(ref, "branch") do
      branch when is_map(branch) -> Data.get(branch, "name")
      _branch -> nil
    end
  end

  defp branch_name(_ref), do: nil

  defp author_id(author) when is_map(author) do
    Data.get(author, "uuid") || Data.get(author, "account_id")
  end

  defp author_id(_author), do: nil

  defp html_url(links) when is_map(links) do
    case Data.get(links, "html") do
      html when is_map(html) -> Data.get(html, "href")
      _html -> nil
    end
  end

  defp html_url(_links), do: nil

  defp optional_https_url(nil), do: {:ok, nil}
  defp optional_https_url(url), do: https_url(url)

  defp https_url(url) when is_binary(url) do
    uri = URI.parse(url)

    if uri.scheme == "https" and is_binary(uri.host) and uri.host != "" and
         is_nil(uri.userinfo) do
      {:ok, url}
    else
      :error
    end
  end

  defp https_url(_url), do: :error

  defp iso8601?(value) when is_binary(value) do
    match?({:ok, _datetime, _offset}, DateTime.from_iso8601(value))
  end

  defp iso8601?(_value), do: false

  defp non_empty_string?(value), do: is_binary(value) and value != ""

  defp valid_integer?(value, minimum, :infinity),
    do: is_integer(value) and value >= minimum

  defp valid_integer?(value, minimum, maximum),
    do: is_integer(value) and value >= minimum and value <= maximum
end
