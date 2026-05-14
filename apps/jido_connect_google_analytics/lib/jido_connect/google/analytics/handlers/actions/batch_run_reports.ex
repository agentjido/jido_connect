defmodule Jido.Connect.Google.Analytics.Handlers.Actions.BatchRunReports do
  @moduledoc false

  alias Jido.Connect.Google.Analytics.Handlers.Actions.{ReportRequest, ResourceHelpers}

  def run(input, %{credentials: credentials}) do
    with {:ok, params} <- ReportRequest.batch_run_reports_input(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, result} <- client.batch_run_reports(params, Map.get(credentials, :access_token)) do
      {:ok, ResourceHelpers.public_map(result)}
    end
  end
end
