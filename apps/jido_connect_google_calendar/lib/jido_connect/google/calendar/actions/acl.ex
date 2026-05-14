defmodule Jido.Connect.Google.Calendar.Actions.Acl do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @acl_readonly_scope "https://www.googleapis.com/auth/calendar.acls.readonly"
  @acl_scope "https://www.googleapis.com/auth/calendar.acls"
  @scope_resolver Jido.Connect.Google.Calendar.ScopeResolver
  @roles ["none", "freeBusyReader", "reader", "writer", "owner"]
  @scope_types ["default", "user", "group", "domain"]

  actions do
    action :list_acl do
      id("google.calendar.acl.list")
      resource(:acl)
      verb(:list)
      data_classification(:personal_data)
      label("List ACL rules")
      description("List access control rules for a Google Calendar calendar.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.ListAcl)
      effect(:read)

      access do
        auth(:user)
        scopes([@acl_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:page_size, :integer, default: 100)
        field(:page_token, :string)
        field(:fields, :string)
        field(:show_deleted, :boolean, default: false)
        field(:sync_token, :string)
      end

      output do
        field(:acl_rules, {:array, :map})
        field(:next_page_token, :string)
        field(:next_sync_token, :string)
      end
    end

    action :get_acl do
      id("google.calendar.acl.get")
      resource(:acl)
      verb(:get)
      data_classification(:personal_data)
      label("Get ACL rule")
      description("Fetch one access control rule for a Google Calendar calendar.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.GetAcl)
      effect(:read)

      access do
        auth(:user)
        scopes([@acl_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:acl_rule_id, :string, required?: true)
        field(:fields, :string)
      end

      output do
        field(:acl_rule, :map)
      end
    end

    action :create_acl do
      id("google.calendar.acl.create")
      resource(:acl)
      verb(:share)
      data_classification(:personal_data)
      label("Create ACL rule")
      description("Create an access control rule for a Google Calendar calendar.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.CreateAcl)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@acl_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:role, :string, required?: true, enum: @roles)
        field(:scope_type, :string, required?: true, enum: @scope_types)
        field(:scope_value, :string)
        field(:send_notifications, :boolean)
      end

      output do
        field(:acl_rule, :map)
      end
    end

    action :patch_acl do
      id("google.calendar.acl.patch")
      resource(:acl)
      verb(:share)
      data_classification(:personal_data)
      label("Patch ACL rule")
      description("Patch an access control rule for a Google Calendar calendar.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.PatchAcl)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@acl_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:acl_rule_id, :string, required?: true)
        field(:role, :string, enum: @roles)
        field(:scope_type, :string, enum: @scope_types)
        field(:scope_value, :string)
        field(:send_notifications, :boolean)
      end

      output do
        field(:acl_rule, :map)
      end
    end

    action :update_acl do
      id("google.calendar.acl.update")
      resource(:acl)
      verb(:share)
      data_classification(:personal_data)
      label("Update ACL rule")
      description("Replace an access control rule for a Google Calendar calendar.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.UpdateAcl)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@acl_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:acl_rule_id, :string, required?: true)
        field(:role, :string, required?: true, enum: @roles)
        field(:scope_type, :string, required?: true, enum: @scope_types)
        field(:scope_value, :string)
        field(:send_notifications, :boolean)
      end

      output do
        field(:acl_rule, :map)
      end
    end

    action :delete_acl do
      id("google.calendar.acl.delete")
      resource(:acl)
      verb(:delete)
      data_classification(:personal_data)
      label("Delete ACL rule")
      description("Delete an access control rule for a Google Calendar calendar.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.DeleteAcl)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@acl_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")
        field(:acl_rule_id, :string, required?: true)
      end

      output do
        field(:result, :map)
      end
    end
  end
end
