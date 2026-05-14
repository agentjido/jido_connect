defmodule Jido.Connect.Google.Contacts.Actions.Directory do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @directory_readonly_scope "https://www.googleapis.com/auth/directory.readonly"
  @scope_resolver Jido.Connect.Google.Contacts.ScopeResolver

  actions do
    action :list_directory_people do
      id("google.contacts.directory.list")
      resource(:directory)
      verb(:list)
      data_classification(:personal_data)
      label("List directory people")
      description("List domain profiles and domain shared contacts from Google People API.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.ListDirectoryPeople)
      effect(:read)

      access do
        auth(:user)
        scopes([@directory_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:page_size, :integer, default: 100)
        field(:page_token, :string)
        field(:read_mask, :string)
        field(:fields, :string)
        field(:sources, {:array, :string})
        field(:merge_sources, {:array, :string})
        field(:request_sync_token, :boolean, default: false)
        field(:sync_token, :string)
      end

      output do
        field(:people, {:array, :map})
        field(:next_page_token, :string)
        field(:next_sync_token, :string)
      end
    end

    action :search_directory_people do
      id("google.contacts.directory.search")
      resource(:directory)
      verb(:search)
      data_classification(:personal_data)
      label("Search directory people")
      description("Search domain profiles and domain shared contacts from Google People API.")
      handler(Jido.Connect.Google.Contacts.Handlers.Actions.SearchDirectoryPeople)
      effect(:read)

      access do
        auth(:user)
        scopes([@directory_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:query, :string, required?: true, example: "Ada")
        field(:page_size, :integer, default: 10)
        field(:page_token, :string)
        field(:read_mask, :string)
        field(:fields, :string)
        field(:sources, {:array, :string})
        field(:merge_sources, {:array, :string})
      end

      output do
        field(:people, {:array, :map})
        field(:next_page_token, :string)
        field(:total_size, :integer)
      end
    end
  end
end
