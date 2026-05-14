defmodule Jido.Connect.Google.Analytics.Handlers.Actions.RunReport do
  @moduledoc false

  alias Jido.Connect.Google.Analytics.Handlers.Actions.{ReportRequest, ResourceHelpers}

  def run(input, %{credentials: credentials}) do
    with {:ok, params} <- ReportRequest.run_report_input(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, report} <- client.run_report(params, Map.get(credentials, :access_token)) do
      {:ok, %{report: ResourceHelpers.public_map(report)}}
    end
  end
end
