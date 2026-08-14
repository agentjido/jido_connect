defmodule Jido.Connect.Google.Drive.Handlers.Actions.UploadFile do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Google.Drive.Client.Params
  alias Jido.Connect.Google.Drive.Handlers.Actions.FileMutation

  def run(input, %{credentials: credentials}) do
    with {:ok, content} <- decode_content(input),
         :ok <- Params.validate_file_upload_size(content) do
      input
      |> Map.delete(:content_base64)
      |> Map.put(:content, content)
      |> FileMutation.run(credentials, :upload_file)
    end
  end

  defp decode_content(input) do
    case {Map.get(input, :content), Map.get(input, :content_base64)} do
      {content, nil} when is_binary(content) ->
        {:ok, content}

      {nil, content_base64} when is_binary(content_base64) ->
        decode_base64(content_base64)

      {content, content_base64} when is_binary(content) and is_binary(content_base64) ->
        invalid_content("Google Drive file upload accepts content or content_base64, not both")

      _invalid ->
        invalid_content("Google Drive file upload requires content or content_base64")
    end
  end

  defp decode_base64(content_base64) do
    case Base.decode64(content_base64, ignore: :whitespace) do
      {:ok, content} ->
        {:ok, content}

      :error ->
        {:error,
         Error.validation("Google Drive file upload content must be valid base64",
           reason: :invalid_upload_content,
           subject: :content_base64
         )}
    end
  end

  defp invalid_content(message) do
    {:error,
     Error.validation(message,
       reason: :invalid_upload_content,
       subject: :content
     )}
  end
end
