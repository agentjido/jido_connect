defmodule Jido.Connect.Google.Drive.Query do
  @moduledoc "Google Drive provider-specific file query filter compiler."

  alias Jido.Connect.{Data, Error}

  @filter_schema Zoi.object(
                   %{
                     name: Zoi.string() |> Zoi.optional(),
                     name_contains: Zoi.string() |> Zoi.optional(),
                     mime_type: Zoi.string() |> Zoi.optional(),
                     parent_id: Zoi.string() |> Zoi.optional(),
                     trashed: Zoi.boolean() |> Zoi.optional(),
                     starred: Zoi.boolean() |> Zoi.optional(),
                     modified_after: Zoi.string() |> Zoi.optional(),
                     modified_before: Zoi.string() |> Zoi.optional(),
                     created_after: Zoi.string() |> Zoi.optional(),
                     created_before: Zoi.string() |> Zoi.optional()
                   },
                   coerce: true
                 )

  @doc "Returns the provider-specific Zoi schema accepted by `google.drive.files.list`."
  def filter_schema, do: @filter_schema

  @doc "Compiles a Drive-specific filter map into a Google Drive `q` expression."
  def compile_filter(nil), do: {:ok, nil}
  def compile_filter(filter) when filter == %{}, do: {:ok, nil}

  def compile_filter(filter) when is_map(filter) do
    case Zoi.parse(@filter_schema, filter) do
      {:ok, parsed} ->
        {:ok, parsed |> filter_clauses() |> join_clauses()}

      {:error, errors} ->
        {:error,
         Error.validation("Invalid Google Drive file filter",
           reason: :invalid_drive_filter,
           details: %{errors: List.wrap(errors)}
         )}
    end
  end

  def compile_filter(_filter) do
    {:error,
     Error.validation("Invalid Google Drive file filter",
       reason: :invalid_drive_filter,
       details: %{expected: :map}
     )}
  end

  @doc "Merges a native Drive query and provider-specific filter into request params."
  def normalize_list_params(params) when is_map(params) do
    with {:ok, filter_query} <- compile_filter(Data.get(params, :filter)) do
      params
      |> Map.delete(:filter)
      |> Map.delete("filter")
      |> put_compiled_query(Data.get(params, :query), filter_query)
      |> then(&{:ok, &1})
    end
  end

  defp filter_clauses(filter) do
    [
      eq("name", Data.get(filter, :name)),
      contains("name", Data.get(filter, :name_contains)),
      eq("mimeType", Data.get(filter, :mime_type)),
      parent(Data.get(filter, :parent_id)),
      bool("trashed", Data.get(filter, :trashed)),
      bool("starred", Data.get(filter, :starred)),
      compare("modifiedTime", ">", Data.get(filter, :modified_after)),
      compare("modifiedTime", "<", Data.get(filter, :modified_before)),
      compare("createdTime", ">", Data.get(filter, :created_after)),
      compare("createdTime", "<", Data.get(filter, :created_before))
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp eq(_field, nil), do: nil
  defp eq(field, value), do: "#{field} = '#{escape(value)}'"

  defp contains(_field, nil), do: nil
  defp contains(field, value), do: "#{field} contains '#{escape(value)}'"

  defp parent(nil), do: nil
  defp parent(parent_id), do: "'#{escape(parent_id)}' in parents"

  defp bool(_field, nil), do: nil
  defp bool(field, value) when is_boolean(value), do: "#{field} = #{value}"

  defp compare(_field, _operator, nil), do: nil
  defp compare(field, operator, value), do: "#{field} #{operator} '#{escape(value)}'"

  defp join_clauses([]), do: nil
  defp join_clauses(clauses), do: Enum.join(clauses, " and ")

  defp put_compiled_query(params, nil, nil), do: params
  defp put_compiled_query(params, query, nil), do: Map.put(params, :query, query)
  defp put_compiled_query(params, nil, filter_query), do: Map.put(params, :query, filter_query)

  defp put_compiled_query(params, query, filter_query) do
    Map.put(params, :query, "(#{query}) and (#{filter_query})")
  end

  defp escape(value) do
    value
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace("'", "\\'")
  end
end
