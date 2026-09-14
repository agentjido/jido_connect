defmodule Jido.Connect.Demo.Ngrok do
  @moduledoc false

  def public_base_url do
    case System.get_env("JIDO_CONNECT_PUBLIC_BASE_URL") do
      nil -> detect_ngrok_url()
      "" -> detect_ngrok_url()
      url -> url
    end
  end

  def github_urls(base_url \\ public_base_url()) do
    if base_url do
      %{
        base_url: base_url,
        oauth_callback: base_url <> "/integrations/github/oauth/callback",
        setup: base_url <> "/integrations/github/setup",
        setup_complete: base_url <> "/integrations/github/setup/complete",
        webhook: base_url <> "/integrations/github/webhook"
      }
    else
      %{}
    end
  end

  def slack_urls(base_url \\ public_base_url()) do
    if base_url do
      %{
        base_url: base_url,
        oauth_callback: base_url <> "/integrations/slack/oauth/callback",
        events: base_url <> "/integrations/slack/events",
        interactivity: base_url <> "/integrations/slack/interactivity"
      }
    else
      %{}
    end
  end

  def google_urls(base_url \\ public_base_url()) do
    if base_url do
      %{
        base_url: base_url,
        oauth_callback: base_url <> "/integrations/google/oauth/callback"
      }
    else
      %{}
    end
  end

  defp detect_ngrok_url do
    endpoint_config = Application.get_env(:jido_connect_demo, Jido.Connect.DemoWeb.Endpoint, [])
    local_port = get_in(endpoint_config, [:http, :port]) || 4000

    case Jido.Connect.Dev.Ngrok.public_url(local_port) do
      {:ok, url} -> url
      {:error, _error} -> nil
    end
  end
end
