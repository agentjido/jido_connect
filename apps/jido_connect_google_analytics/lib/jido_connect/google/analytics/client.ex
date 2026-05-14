defmodule Jido.Connect.Google.Analytics.Client do
  @moduledoc "Google Analytics API client boundary."

  alias Jido.Connect.Google.Analytics.Client.Metadata

  defdelegate get_metadata(params, access_token), to: Metadata
end
