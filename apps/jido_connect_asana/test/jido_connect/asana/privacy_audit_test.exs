defmodule Jido.Connect.Asana.PrivacyAuditTest do
  @moduledoc """
  Privacy fixture review for Asana test data.

  Verifies that no fixture files contain access tokens, refresh tokens,
  private keys, client secrets, signing secrets, or other sensitive
  credential values. This test runs against all JSON fixture files in
  the Asana fixture directory.

  When new fixtures are added, this test automatically covers them.
  """
  use ExUnit.Case, async: true

  @fixture_dir Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "asana"])

  @sensitive_patterns [
    # Credential patterns that should never appear in fixtures
    ~r/"access_token"/i,
    ~r/"refresh_token"/i,
    ~r/"client_secret"/i,
    ~r/"private_key"/i,
    ~r/"signing_secret"/i,
    ~r/"api_key"/i,
    ~r/"password"/i,
    ~r/"secret"/i,
    # Bearer token patterns
    ~r/Bearer\s+[A-Za-z0-9\-._~+\/]+=*/i,
    # Asana PAT pattern (looks like a long numeric token)
    ~r/[0-9]{10,}\/[a-zA-Z0-9]{20,}/
  ]

  describe "fixture privacy review" do
    test "no fixture files contain sensitive credential patterns" do
      for fixture_path <- fixture_files() do
        content = File.read!(fixture_path)
        relative = Path.relative_to(fixture_dir(), fixture_path)

        for pattern <- @sensitive_patterns do
          refute Regex.match?(pattern, content),
                 "Fixture #{relative} contains a sensitive pattern matching #{inspect(pattern)}"
        end
      end
    end

    test "all fixture files parse as valid JSON" do
      for fixture_path <- fixture_files() do
        relative = Path.relative_to(fixture_dir(), fixture_path)
        content = File.read!(fixture_path)

        assert {:ok, _parsed} = Jason.decode(content),
               "Fixture #{relative} is not valid JSON"
      end
    end

    test "normalizer round-trips all fixture files without exposing credentials" do
      alias Jido.Connect.Asana.Normalizer

      normalizers = %{
        "workspace" => &Normalizer.workspace/1,
        "project" => &Normalizer.project/1,
        "task" => &Normalizer.task/1,
        "section" => &Normalizer.section/1,
        "user" => &Normalizer.user/1,
        "story" => &Normalizer.story/1,
        "tag" => &Normalizer.tag/1,
        "custom_field" => &Normalizer.custom_field/1,
        "pagination" => &Normalizer.pagination/1
      }

      for fixture_path <- fixture_files() do
        name = Path.basename(fixture_path, ".json")
        relative = Path.relative_to(fixture_dir(), fixture_path)
        payload = File.read!(fixture_path) |> Jason.decode!()

        # Find a matching normalizer by checking if the fixture name starts with a key
        {_key, normalizer} =
          Enum.find(normalizers, {nil, nil}, fn {prefix, _} ->
            String.starts_with?(name, prefix)
          end)

        if normalizer do
          assert {:ok, _struct} = normalizer.(payload),
                 "Fixture #{relative} failed to normalize"
        end
      end
    end
  end

  defp fixture_files do
    Path.join(fixture_dir(), "**/*.json")
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp fixture_dir, do: @fixture_dir
end
