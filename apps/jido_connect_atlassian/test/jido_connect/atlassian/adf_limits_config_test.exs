defmodule Jido.Connect.Atlassian.ADFLimitsConfigTest do
  # Changes application configuration, so it cannot run concurrently.
  use ExUnit.Case, async: false

  alias Jido.Connect.Atlassian.ADF
  alias Jido.Connect.Error

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/doc/
  @document %{
    "version" => 1,
    "type" => "doc",
    "content" => [
      %{"type" => "paragraph", "content" => [%{"type" => "text", "text" => "Hello world"}]}
    ]
  }

  setup do
    previous = Application.fetch_env(:jido_connect_atlassian, ADF)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:jido_connect_atlassian, ADF, value)
        :error -> Application.delete_env(:jido_connect_atlassian, ADF)
      end
    end)
  end

  test "uses the built-in defaults without configuration" do
    Application.delete_env(:jido_connect_atlassian, ADF)

    assert ADF.default_limits() == [max_depth: 64, max_nodes: 50_000]
  end

  test "applies configured defaults when a caller passes no limits" do
    Application.put_env(:jido_connect_atlassian, ADF, max_depth: 1, max_nodes: 10)

    assert ADF.default_limits() == [max_depth: 1, max_nodes: 10]

    assert {:error, %Error.ValidationError{reason: :adf_depth_limit_exceeded}} =
             ADF.project(@document, on_unsupported: :degrade)

    assert {:ok, %{text: "Hello world"}} = ADF.project(@document, max_depth: 2)
  end
end
