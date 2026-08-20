defmodule Jido.Connect.Confluence.Input.Pages do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Confluence.Contract

  @identifier_max Contract.maximum_identifier_length()
  @title_max Contract.maximum_title_length()
  @markdown_max Contract.maximum_markdown_length()
  @cursor_max Contract.maximum_cursor_length()
  @version_message_max Contract.maximum_version_message_length()
  @default_limit Contract.default_limit()
  @maximum_limit Contract.maximum_limit()
  @default_max_characters Contract.default_max_characters()
  @maximum_max_characters Contract.maximum_max_characters()

  def validate_list(input) when is_map(input) do
    normalized = %{
      space_key: Data.get(input, :space_key),
      limit: Data.get(input, :limit) || @default_limit,
      cursor: Data.get(input, :cursor)
    }

    with :ok <- required_string(:space_key, normalized.space_key, @identifier_max),
         :ok <- integer(:limit, normalized.limit, 1, @maximum_limit),
         :ok <- optional_string(:cursor, normalized.cursor, @cursor_max) do
      {:ok, normalized}
    end
  end

  def validate_list(_input), do: invalid(:input)

  def validate_get(input) when is_map(input) do
    normalized = %{
      id: Data.get(input, :id),
      max_characters: Data.get(input, :max_characters) || @default_max_characters
    }

    with :ok <- required_string(:id, normalized.id, @identifier_max),
         :ok <- integer(:max_characters, normalized.max_characters, 1, @maximum_max_characters) do
      {:ok, normalized}
    end
  end

  def validate_get(_input), do: invalid(:input)

  def validate_create(input) when is_map(input) do
    normalized = %{
      title: Data.get(input, :title),
      space_key: Data.get(input, :space_key),
      markdown: Data.get(input, :markdown),
      parent_id: Data.get(input, :parent_id)
    }

    with :ok <- required_string(:title, normalized.title, @title_max),
         :ok <- required_string(:space_key, normalized.space_key, @identifier_max),
         :ok <- bounded_string(:markdown, normalized.markdown, @markdown_max),
         :ok <- optional_string(:parent_id, normalized.parent_id, @identifier_max) do
      {:ok, normalized}
    end
  end

  def validate_create(_input), do: invalid(:input)

  def validate_update(input) when is_map(input) do
    normalized = %{
      id: Data.get(input, :id),
      space_key: Data.get(input, :space_key),
      markdown: Data.get(input, :markdown),
      last_pushed_version: Data.get(input, :last_pushed_version),
      force: Data.get(input, :force) || false,
      title: Data.get(input, :title),
      version_message: Data.get(input, :version_message)
    }

    with :ok <- required_string(:id, normalized.id, @identifier_max),
         :ok <- required_string(:space_key, normalized.space_key, @identifier_max),
         :ok <- bounded_string(:markdown, normalized.markdown, @markdown_max),
         :ok <- integer(:last_pushed_version, normalized.last_pushed_version, 1, :infinity),
         :ok <- boolean(:force, normalized.force),
         :ok <- optional_string(:title, normalized.title, @title_max),
         :ok <-
           optional_string(:version_message, normalized.version_message, @version_message_max) do
      {:ok, normalized}
    end
  end

  def validate_update(_input), do: invalid(:input)

  def validate_delete(input) when is_map(input) do
    id = Data.get(input, :id)

    if bounded_non_blank?(id, @identifier_max), do: {:ok, %{id: id}}, else: invalid(:id)
  end

  def validate_delete(_input), do: invalid(:input)

  defp required_string(field, value, maximum) do
    if bounded_non_blank?(value, maximum), do: :ok, else: invalid(field)
  end

  defp bounded_string(field, value, maximum) do
    if is_binary(value) and String.length(value) <= maximum, do: :ok, else: invalid(field)
  end

  defp optional_string(_field, nil, _maximum), do: :ok
  defp optional_string(field, value, maximum), do: required_string(field, value, maximum)

  defp integer(_field, value, minimum, :infinity) when is_integer(value) and value >= minimum,
    do: :ok

  defp integer(_field, value, minimum, maximum)
       when is_integer(value) and value >= minimum and value <= maximum,
       do: :ok

  defp integer(field, _value, _minimum, _maximum), do: invalid(field)

  defp boolean(_field, value) when is_boolean(value), do: :ok
  defp boolean(field, _value), do: invalid(field)

  defp bounded_non_blank?(value, maximum) do
    is_binary(value) and String.trim(value) != "" and String.length(value) <= maximum
  end

  defp invalid(field) do
    {:error,
     Error.validation("Invalid Confluence page input",
       reason: :invalid_confluence_input,
       subject: field,
       details: %{field: field}
     )}
  end
end
