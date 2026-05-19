defmodule Jido.Connect.DemoWeb.Router do
  use Jido.Connect.DemoWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {Jido.Connect.DemoWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", Jido.Connect.DemoWeb do
    pipe_through(:browser)

    get("/", PageController, :home)
    get("/integrations/github/setup", IntegrationController, :github_setup)
    get("/integrations/github/setup/complete", IntegrationController, :github_setup_complete)
    get("/integrations/github/oauth/start", IntegrationController, :github_oauth_start)
    get("/integrations/github/oauth/callback", IntegrationController, :github_oauth_callback)
    get("/integrations/github", IntegrationController, :github_show)
    get("/integrations/google", IntegrationController, :google_show)
    get("/integrations/google/oauth/start", IntegrationController, :google_oauth_start)
    get("/integrations/google/oauth/callback", IntegrationController, :google_oauth_callback)
    get("/integrations/slack", IntegrationController, :slack_show)
    get("/integrations/slack/oauth/callback", IntegrationController, :slack_oauth_callback)

    post(
      "/integrations/github/connections/manual",
      IntegrationController,
      :github_manual_connection
    )

    post("/integrations/slack/connections/bot", IntegrationController, :slack_bot_connection)

    post(
      "/integrations/google/connections/manual",
      IntegrationController,
      :google_manual_connection
    )

    post("/integrations/github/actions/list_issues", IntegrationController, :github_list_issues)
    post("/integrations/github/actions/create_issue", IntegrationController, :github_create_issue)
    post("/integrations/google/actions/get_values", IntegrationController, :google_get_values)
    post("/integrations/google/actions/gmail_list_messages", IntegrationController, :google_gmail_list_messages)
    post("/integrations/google/actions/gmail_get_profile", IntegrationController, :google_gmail_get_profile)
    post("/integrations/google/actions/drive_list_files", IntegrationController, :google_drive_list_files)
    post("/integrations/google/actions/drive_get_about", IntegrationController, :google_drive_get_about)
    post("/integrations/google/actions/calendar_list_events", IntegrationController, :google_calendar_list_events)
    post("/integrations/google/actions/calendar_list_calendars", IntegrationController, :google_calendar_list_calendars)
    post("/integrations/slack/actions/list_channels", IntegrationController, :slack_list_channels)
    post("/integrations/slack/actions/post_message", IntegrationController, :slack_post_message)

    post(
      "/integrations/github/sensors/new_issues/poll",
      IntegrationController,
      :github_poll_new_issues
    )
  end

  scope "/", Jido.Connect.DemoWeb do
    pipe_through(:api)

    get("/health", IntegrationController, :health)
    get("/integrations", IntegrationController, :index)
    get("/integrations/catalog", IntegrationController, :catalog)
    post("/integrations/github/webhook", IntegrationController, :github_webhook)
    post("/integrations/slack/events", IntegrationController, :slack_events)
    post("/integrations/slack/interactivity", IntegrationController, :slack_interactivity)
  end
end
