defmodule Jido.Connect.Google.Meet.Client.Params do
  @moduledoc "Google Meet request parameter helpers."

  alias Jido.Connect.Data

  @doc "Builds query params for Meet requests that support partial response fields."
  def fields_params(params) do
    %{
      fields: Data.get(params, :fields)
    }
    |> Data.compact()
  end

  @doc "Builds a Google Meet Space request body."
  def space_body(params) do
    %{
      config: config_body(params)
    }
    |> Data.compact()
  end

  defp config_body(params) do
    raw_config =
      case Data.get(params, :config, %{}) do
        config when is_map(config) -> config
        _other -> %{}
      end

    generated_config =
      %{
        "accessType" => Data.get(params, :access_type),
        "entryPointAccess" => Data.get(params, :entry_point_access),
        "moderation" => Data.get(params, :moderation),
        "moderationRestrictions" => Data.get(params, :moderation_restrictions),
        "attendanceReportGenerationType" => Data.get(params, :attendance_report_generation_type),
        "artifactConfig" => Data.get(params, :artifact_config)
      }
      |> Data.compact()

    raw_config
    |> Map.merge(generated_config)
    |> empty_to_nil()
  end

  defp empty_to_nil(map) when map == %{}, do: nil
  defp empty_to_nil(map), do: map
end
