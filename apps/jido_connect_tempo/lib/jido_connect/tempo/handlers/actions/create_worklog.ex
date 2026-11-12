defmodule Jido.Connect.Tempo.Handlers.Actions.CreateWorklog do
  @moduledoc false

  # The author must be the connection's subject.account_id, bound in the
  # request. The input is checked before the provider client is resolved, so
  # an injected client never receives an invalid or foreign worklog. The
  # client sends one POST and never retries it.

  alias Jido.Connect.Tempo.{Client, Worklog}
  alias Jido.Connect.Tempo.Input.NewWorklog

  def run(input, runtime) do
    with {:ok, request} <- Client.request_context(runtime),
         {:ok, worklog} <- NewWorklog.parse(input),
         {:ok, _worklog} <-
           NewWorklog.check_author(worklog, request.account_id, request.connection_id),
         client = Client.resolve(runtime),
         {:ok, worklog} <- client.create_worklog(request, input) do
      {:ok, %{worklog: Worklog.to_map(worklog)}}
    end
  end
end
