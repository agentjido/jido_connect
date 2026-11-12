defmodule Jido.Connect.Jira.Client.Normalizer.IssueFields do
  @moduledoc false

  # Finds the requested Jira field keys that an issue payload does not carry.
  # Jira returns `null` for a known field without a value and leaves out a
  # requested field it does not return, such as `parent` on a top-level issue,
  # a field that the site's field configuration hides, or a key that does not
  # exist on the site.

  alias Jido.Connect.Data

  # The `fields` keys that `Normalizer.issue/2` reads; `*all` stands for them.
  @read_keys ~w(summary description status issuetype project assignee reporter priority
                labels components fixVersions duedate resolution timetracking created updated)

  # `*navigable` stands for the read keys that `GET /rest/api/3/field` marks as
  # navigable; `timetracking` is the only one it does not.
  @navigable_keys @read_keys -- ~w(timetracking)

  # Top-level issue properties that callers sometimes list as fields.
  @top_level_keys ~w(id key self expand)

  @doc """
  Returns the requested keys that `fields` does not contain, in request order.

  `requested` is the `fields` list of the request, or `nil` when nothing was
  requested. Entries can hold comma-separated keys. `*all` stands for the keys
  the normalizer reads and `*navigable` for those of them that Jira counts as
  navigable; other `*` selectors are skipped. `-key` removes a key. A list
  that names no key or selector, such as `["-description"]`, starts from
  `*all`, as an issue read does; enhanced search starts such a list from
  `*navigable`, so its caller passes `["*navigable" | list]`.
  """
  @spec missing(term(), [String.t()] | nil) :: [String.t()]
  def missing(_fields, nil), do: []

  def missing(fields, requested) when is_list(requested) do
    fields = if is_map(fields), do: fields, else: %{}

    requested
    |> keys()
    |> Enum.filter(&(Data.get(fields, &1, :missing) == :missing))
  end

  @doc """
  Splits a `fields` list into the keys and selectors it names and the keys it
  excludes with `-`, both trimmed and in request order.
  """
  @spec split([String.t()]) :: {[String.t()], [String.t()]}
  def split(requested) when is_list(requested) do
    {excluded, included} =
      requested
      |> Enum.flat_map(&String.split(to_string(&1), ","))
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.split_with(&String.starts_with?(&1, "-"))

    {included, Enum.map(excluded, &String.trim_leading(&1, "-"))}
  end

  defp keys(requested) do
    {included, excluded} =
      case split(requested) do
        {[], excluded} -> {["*all"], excluded}
        split -> split
      end

    included
    |> Enum.flat_map(&expand/1)
    |> Enum.uniq()
    |> Enum.reject(&(&1 in excluded or &1 in @top_level_keys))
  end

  defp expand("*all"), do: @read_keys
  defp expand("*navigable"), do: @navigable_keys
  defp expand("*" <> _selector), do: []
  defp expand(key), do: [key]
end
