defmodule Jido.Connect.Google.Sheets.Client.Params do
  @moduledoc "Google Sheets request parameter helpers."

  def spreadsheet_get_params(params) when is_map(params) do
    []
    |> put_repeated(:ranges, Map.get(params, :ranges, []))
    |> maybe_put(:includeGridData, Map.get(params, :include_grid_data))
  end

  def values_get_params(params) when is_map(params) do
    []
    |> maybe_put(:majorDimension, Map.get(params, :major_dimension))
    |> maybe_put(:valueRenderOption, Map.get(params, :value_render_option))
    |> maybe_put(:dateTimeRenderOption, Map.get(params, :date_time_render_option))
  end

  def values_batch_get_params(params) when is_map(params) do
    []
    |> put_repeated(:ranges, Map.get(params, :ranges, []))
    |> maybe_put(:majorDimension, Map.get(params, :major_dimension))
    |> maybe_put(:valueRenderOption, Map.get(params, :value_render_option))
    |> maybe_put(:dateTimeRenderOption, Map.get(params, :date_time_render_option))
  end

  def values_update_params(params) when is_map(params) do
    []
    |> maybe_put(:valueInputOption, Map.get(params, :value_input_option, "RAW"))
    |> maybe_put(:includeValuesInResponse, Map.get(params, :include_values_in_response))
    |> maybe_put(:responseValueRenderOption, Map.get(params, :response_value_render_option))
    |> maybe_put(
      :responseDateTimeRenderOption,
      Map.get(params, :response_date_time_render_option)
    )
  end

  def values_append_params(params) when is_map(params) do
    params
    |> values_update_params()
    |> maybe_put(:insertDataOption, Map.get(params, :insert_data_option))
  end

  defp put_repeated(params, _key, nil), do: params
  defp put_repeated(params, _key, []), do: params

  defp put_repeated(params, key, values) when is_list(values),
    do: params ++ Enum.map(values, &{key, &1})

  defp put_repeated(params, key, value), do: Keyword.put(params, key, value)

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, _key, ""), do: params
  defp maybe_put(params, key, value), do: Keyword.put(params, key, value)
end
