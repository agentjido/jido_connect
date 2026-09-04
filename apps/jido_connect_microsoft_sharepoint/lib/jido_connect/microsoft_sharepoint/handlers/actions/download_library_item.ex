defmodule Jido.Connect.MicrosoftSharepoint.Handlers.Actions.DownloadLibraryItem do
  @moduledoc false

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DownloadContent

  def run(input, context) do
    with {:ok, content} <- DownloadContent.run(input, context) do
      {:ok, %{content: content}}
    end
  end
end
