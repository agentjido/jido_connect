defmodule Jido.Connect.GitLab.Webhook do
  @moduledoc """
  Pure helpers for GitLab webhook event verification and normalization.

  GitLab webhooks deliver JSON payloads with a `X-Gitlab-Token` header for
  secret-token verification and a `X-Gitlab-Event` header for the event type.
  Hosts verify the token before using these helpers to normalize the accepted
  delivery into trigger signals.

  This module does **not** store or expose the webhook secret token.
  Verification receives a pre-extracted token from the host layer.

  ## Supported Events

  - **Push** (`Push Hook`) — branch push
  - **Issue** (`Issue Hook`) — issue opened/closed/reopened/updated
  - **Merge Request** (`Merge Request Hook`) — MR opened/closed/merged/updated
  - **Note** (`Note Hook`) — comment on issue, MR, or snippet
  - **Pipeline** (`Pipeline Hook`) — CI/CD pipeline status change
  - **Job** (`Job Hook`) — CI/CD job status change
  """

  alias Jido.Connect.{Data, Error}

  @supported_events ~w(push issue merge_request note pipeline job)a

  @doc "Returns the list of supported GitLab webhook event types."
  @spec supported_events() :: [String.t()]
  def supported_events, do: @supported_events

  @doc """
  Verifies the GitLab webhook secret token.

  Returns `:ok` when the provided token matches the expected secret,
  or an error otherwise. The host extracts the `X-Gitlab-Token` header;
  neither the secret nor the raw request are passed through this module.
  """
  @spec verify_token(provided :: String.t(), expected :: String.t()) ::
          :ok | {:error, Error.ProviderError.t()}
  def verify_token(provided, expected)
      when is_binary(provided) and is_binary(expected) do
    if secure_compare?(provided, expected) do
      :ok
    else
      {:error,
       Error.provider("GitLab webhook token verification failed",
         provider: :gitlab,
         reason: :webhook_token_mismatch
       )}
    end
  end

  def verify_token(_provided, _expected) do
    {:error,
     Error.provider("GitLab webhook token is missing",
       provider: :gitlab,
       reason: :webhook_token_missing
     )}
  end

  @doc """
  Parses the `X-Gitlab-Event` header value into a normalized event type atom.

  Returns `{:ok, atom}` or `{:error, _}`.
  """
  @spec parse_event_type(String.t()) :: {:ok, atom()} | {:error, Error.ProviderError.t()}
  def parse_event_type("Push Hook"), do: {:ok, :push}
  def parse_event_type("Issue Hook"), do: {:ok, :issue}
  def parse_event_type("Merge Request Hook"), do: {:ok, :merge_request}
  def parse_event_type("Note Hook"), do: {:ok, :note}
  def parse_event_type("Pipeline Hook"), do: {:ok, :pipeline}
  def parse_event_type("Job Hook"), do: {:ok, :job}
  def parse_event_type("Tag Push Hook"), do: {:ok, :tag_push}
  def parse_event_type("Wiki Page Hook"), do: {:ok, :wiki_page}

  def parse_event_type(other) when is_binary(other) do
    {:error,
     Error.provider("Unsupported GitLab webhook event type",
       provider: :gitlab,
       reason: :unsupported_webhook_event,
       details: %{header: other}
     )}
  end

  def parse_event_type(_other) do
    {:error,
     Error.provider("GitLab webhook event type header is missing",
       provider: :gitlab,
       reason: :webhook_event_missing
     )}
  end

  @doc """
  Normalizes a GitLab webhook event payload into a signal map.

  Returns `{:ok, signal_map}` on success, or `{:error, _}` on failure.
  """
  @spec normalize_event(atom(), map()) :: {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_event(:push, payload) when is_map(payload) do
    signal =
      %{
        event_type: :push,
        ref: Data.get(payload, "ref"),
        before: Data.get(payload, "before"),
        after: Data.get(payload, "after"),
        project_id: get_in(payload, ["project", "id"]),
        project_path: get_in(payload, ["project", "path_with_namespace"]),
        user_name: Data.get(payload, "user_name"),
        commits: Data.get(payload, "commits"),
        total_commits_count: Data.get(payload, "total_commits_count")
      }
      |> Data.compact()

    {:ok, signal}
  end

  def normalize_event(:issue, %{"object_attributes" => attrs} = payload)
      when is_map(attrs) do
    signal =
      %{
        event_type: :issue,
        action: Data.get(attrs, "action"),
        issue_id: Data.get(attrs, "id"),
        issue_iid: Data.get(attrs, "iid"),
        title: Data.get(attrs, "title"),
        state: Data.get(attrs, "state"),
        project_id: Data.get(attrs, "project_id"),
        author_id: get_in(payload, ["user", "id"]),
        author_username: get_in(payload, ["user", "username"]),
        labels: normalize_label_names(Data.get(payload, "labels")),
        created_at: Data.get(attrs, "created_at"),
        updated_at: Data.get(attrs, "updated_at")
      }
      |> Data.compact()

    {:ok, signal}
  end

  def normalize_event(:merge_request, %{"object_attributes" => attrs} = payload)
      when is_map(attrs) do
    signal =
      %{
        event_type: :merge_request,
        action: Data.get(attrs, "action"),
        merge_request_id: Data.get(attrs, "id"),
        merge_request_iid: Data.get(attrs, "iid"),
        title: Data.get(attrs, "title"),
        state: Data.get(attrs, "state"),
        merge_status: Data.get(attrs, "merge_status"),
        source_branch: Data.get(attrs, "source_branch"),
        target_branch: Data.get(attrs, "target_branch"),
        project_id: Data.get(attrs, "project_id"),
        source_project_id: Data.get(attrs, "source_project_id"),
        target_project_id: Data.get(attrs, "target_project_id"),
        author_id: get_in(payload, ["user", "id"]),
        author_username: get_in(payload, ["user", "username"]),
        created_at: Data.get(attrs, "created_at"),
        updated_at: Data.get(attrs, "updated_at"),
        merged_at: Data.get(attrs, "merged_at")
      }
      |> Data.compact()

    {:ok, signal}
  end

  def normalize_event(:note, %{"object_attributes" => attrs} = payload)
      when is_map(attrs) do
    signal =
      %{
        event_type: :note,
        note_id: Data.get(attrs, "id"),
        noteable_type: Data.get(attrs, "noteable_type"),
        noteable_id: Data.get(attrs, "noteable_id"),
        body: Data.get(attrs, "note"),
        author_id: get_in(payload, ["user", "id"]),
        author_username: get_in(payload, ["user", "username"]),
        project_id: Data.get(attrs, "project_id"),
        created_at: Data.get(attrs, "created_at"),
        updated_at: Data.get(attrs, "updated_at")
      }
      |> Data.compact()

    {:ok, signal}
  end

  def normalize_event(:pipeline, %{"object_attributes" => attrs} = payload)
      when is_map(attrs) do
    signal =
      %{
        event_type: :pipeline,
        pipeline_id: Data.get(attrs, "id"),
        status: Data.get(attrs, "status"),
        ref: Data.get(attrs, "ref"),
        sha: Data.get(attrs, "sha"),
        source: Data.get(attrs, "source"),
        project_id: Data.get(attrs, "project_id"),
        user_id: get_in(payload, ["user", "id"]),
        user_username: get_in(payload, ["user", "username"]),
        created_at: Data.get(attrs, "created_at"),
        finished_at: Data.get(attrs, "finished_at")
      }
      |> Data.compact()

    {:ok, signal}
  end

  def normalize_event(:job, %{"object_attributes" => attrs} = payload)
      when is_map(attrs) do
    signal =
      %{
        event_type: :job,
        job_id: Data.get(attrs, "id"),
        name: Data.get(attrs, "name"),
        stage: Data.get(attrs, "stage"),
        status: Data.get(attrs, "status"),
        ref: Data.get(attrs, "ref"),
        pipeline_id: Data.get(attrs, "pipeline_id"),
        project_id: Data.get(attrs, "project_id"),
        runner_id: get_in(payload, ["runner", "id"]),
        user_id: get_in(payload, ["user", "id"]),
        user_username: get_in(payload, ["user", "username"]),
        created_at: Data.get(attrs, "created_at"),
        finished_at: Data.get(attrs, "finished_at")
      }
      |> Data.compact()

    {:ok, signal}
  end

  def normalize_event(:tag_push, payload) when is_map(payload) do
    signal =
      %{
        event_type: :tag_push,
        ref: Data.get(payload, "ref"),
        before: Data.get(payload, "before"),
        after: Data.get(payload, "after"),
        project_id: get_in(payload, ["project", "id"]),
        project_path: get_in(payload, ["project", "path_with_namespace"]),
        user_name: Data.get(payload, "user_name")
      }
      |> Data.compact()

    {:ok, signal}
  end

  def normalize_event(event_type, _payload) do
    if event_type in @supported_events or event_type == :tag_push or event_type == :wiki_page do
      {:error,
       Error.provider("GitLab webhook event payload is invalid",
         provider: :gitlab,
         reason: :invalid_webhook_event,
         details: %{event_type: event_type}
       )}
    else
      {:error,
       Error.provider("Unsupported GitLab webhook event type",
         provider: :gitlab,
         reason: :unsupported_webhook_event,
         details: %{event_type: event_type}
       )}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp normalize_label_names(nil), do: []

  defp normalize_label_names(labels) when is_list(labels) do
    labels
    |> Enum.map(fn
      %{"title" => name} -> name
      %{"name" => name} -> name
      name when is_binary(name) -> name
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_label_names(_), do: []

  # Constant-time string comparison to prevent timing attacks.
  defp secure_compare?(left, right) when byte_size(left) != byte_size(right), do: false

  defp secure_compare?(left, right) do
    left
    |> :binary.bin_to_list()
    |> Enum.zip(:binary.bin_to_list(right))
    |> Enum.reduce(0, fn {a, b}, acc -> Bitwise.bxor(a, b) + acc end) == 0
  end
end
