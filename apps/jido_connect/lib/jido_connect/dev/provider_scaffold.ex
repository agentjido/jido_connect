defmodule Jido.Connect.Dev.ProviderScaffold do
  @moduledoc """
  Generates a minimal provider package scaffold for connector authors.

  This module backs the `mix jido.connect.gen.provider` task. It is intentionally
  development-only and ignored by package coverage.
  """

  defmodule File do
    @moduledoc false

    @schema Zoi.struct(
              __MODULE__,
              %{
                path: Zoi.string(),
                contents: Zoi.string()
              },
              coerce: true
            )

    @type t :: unquote(Zoi.type_spec(@schema))
    @enforce_keys Zoi.Struct.enforce_keys(@schema)
    defstruct Zoi.Struct.struct_fields(@schema)

    def new!(attrs), do: Zoi.parse!(@schema, attrs)
  end

  @spec files(String.t() | atom()) :: list()
  def files(provider) do
    provider = provider |> to_string() |> String.trim()
    app = "jido_connect_#{provider}"
    module = provider |> Macro.camelize()

    [
      file("#{app}/mix.exs", mix_exs(app, module)),
      file("#{app}/lib/jido_connect/#{provider}/integration.ex", integration(provider, module)),
      file(
        "#{app}/lib/jido_connect/#{provider}/actions/example.ex",
        action_fragment(provider, module)
      ),
      file("#{app}/lib/jido_connect/#{provider}/client.ex", client(module)),
      file("#{app}/lib/jido_connect/#{provider}/oauth.ex", oauth(module)),
      file("#{app}/lib/jido_connect/#{provider}/webhook.ex", webhook(module)),
      file("#{app}/test/jido_connect_#{provider}_test.exs", test(provider, module))
    ]
  end

  @spec write!(Path.t(), String.t() | atom()) :: [Path.t()]
  def write!(root, provider) do
    Enum.map(files(provider), fn %File{} = file ->
      path = Path.join(root, file.path)
      path |> Path.dirname() |> Elixir.File.mkdir_p!()
      Elixir.File.write!(path, file.contents)
      path
    end)
  end

  defp file(path, contents), do: File.new!(%{path: path, contents: contents})

  defp mix_exs(app, module) do
    """
    defmodule JidoConnect#{module}.MixProject do
      use Mix.Project

      def project do
        [
          app: :#{app},
          version: "0.8.0",
          elixir: "~> 1.19",
          deps: deps()
        ]
      end

      def application, do: [extra_applications: [:logger]]

      defp deps do
        [
          {:jido_connect, path: "../jido_connect"},
          {:req, "~> 0.6"}
        ]
      end
    end
    """
  end

  defp integration(provider, module) do
    """
    defmodule Jido.Connect.#{module} do
      use Jido.Connect,
        fragments: [
          Jido.Connect.#{module}.Actions.Example
        ]

      integration do
        id :#{provider}
        name "#{module}"
        description "#{module} connector."
        category :productivity
      end

      catalog do
        package :jido_connect_#{provider}
        status :experimental
        tags [:productivity]
      end

      auth do
        oauth2 :user do
          default? true
          owner :app_user
          subject :user
          setup :oauth2_authorization_code
          authorize_url "https://example.test/oauth/authorize"
          token_url "https://example.test/oauth/token"
          token_field :access_token
          credential_fields [:access_token]
          lease_fields [:access_token]
          scopes []
          default_scopes []
        end
      end

      policies do
        policy :connection_access do
          label "Connection access"
          decision :allow_operation
        end
      end
    end
    """
  end

  defp action_fragment(_provider, module) do
    """
    defmodule Jido.Connect.#{module}.Actions.Example do
      @moduledoc false

      use Spark.Dsl.Fragment, of: Jido.Connect

      actions do
        # action :list_items do
        #   id "example.item.list"
        #   resource :item
        #   verb :list
        #   data_classification :workspace_metadata
        #   label "List items"
        #   handler Jido.Connect.#{module}.Handlers.Actions.ListItems
        #   effect :read
        #
        #   access do
        #     auth :user
        #     policies [:connection_access]
        #     scopes []
        #   end
        # end
      end
    end
    """
  end

  defp client(module) do
    """
    defmodule Jido.Connect.#{module}.Client do
      @moduledoc false
    end
    """
  end

  defp oauth(module) do
    """
    defmodule Jido.Connect.#{module}.OAuth do
      @moduledoc false
    end
    """
  end

  defp webhook(module) do
    """
    defmodule Jido.Connect.#{module}.Webhook do
      @moduledoc false
    end
    """
  end

  defp test(provider, module) do
    """
    defmodule Jido.Connect.#{module}Test do
      use ExUnit.Case, async: true

      test "declares #{provider} integration" do
        assert Jido.Connect.#{module}.integration().id == :#{provider}
      end
    end
    """
  end
end
