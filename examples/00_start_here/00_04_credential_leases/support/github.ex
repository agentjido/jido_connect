defmodule Jido.Connect.Examples.StartHere.CredentialLeases.Fixture do
  @moduledoc false

  def get_pull_request(repo, 42, "fixture-v1")
      when repo in ["example/widgets", "example/gadgets"],
      do: {:ok, %{number: 42, title: "Before rotation"}}

  def get_pull_request(repo, 42, "fixture-v2")
      when repo in ["example/widgets", "example/gadgets"],
      do: {:ok, %{number: 42, title: "After rotation"}}
end
