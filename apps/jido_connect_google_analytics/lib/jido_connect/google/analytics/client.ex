defmodule Jido.Connect.Google.Analytics.Client do
  @moduledoc "Google Analytics API client boundary."

  alias Jido.Connect.Google.Analytics.Client.{Metadata, Reports}

  defdelegate get_metadata(params, access_token), to: Metadata
  defdelegate run_report(params, access_token), to: Reports
  defdelegate batch_run_reports(params, access_token), to: Reports
end
