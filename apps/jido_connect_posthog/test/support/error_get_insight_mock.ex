defmodule Jido.Connect.PostHog.ErrorGetInsightMock do
  @moduledoc false

  def get_insight("nonexistent", "token", _opts) do
    {:ok, %Req.Response{status: 404, body: %{"detail" => "Not found."}}}
  end
end
