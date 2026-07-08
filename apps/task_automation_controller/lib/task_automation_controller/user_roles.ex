defmodule TaskAutomationController.UserRoles do
  @topic "task_automation_controller:user_roles"
  @schema TaskAutomationController.Users.UserRole
  @updated [:task_automation_controller, :user_role, :updated]
  @created [:task_automation_controller, :user_role, :created]
  @deleted [:task_automation_controller, :user_role, :deleted]

  alias TaskAutomationController.{
    Users.User, 
    #Roles,
  }

  # Include default CRUD operations from HfgPortal.Helpers.DefaultCrud
  use HfgPortal.Helpers.DefaultCrud,
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  # Custom Functions
  
  @doc """
  Retrieves a user's role by their user ID.
  Returns a single UserRole record or nil if not found.
  """
  def get(id, :user), do: @schema |> where([u], u.user_id == ^id) |> limit(1) |> Repo.one()

  defp filter_user(query, user_id) when not is_nil(user_id), do: where(query, [u], u.id == ^user_id)
  defp filter_user(query, _), do: query

  defp filter_user_id(query, user_id) when not is_nil(user_id), do: where(query, [u], u.user_id == ^user_id)
  defp filter_user_id(query, _), do: query
  
  defp filter_role_id(query, role_id) when not is_nil(role_id), do: where(query, [u], u.role_id == ^role_id)
  defp filter_role_id(query, _), do: query

  # Override default list function
  @doc """
  Lists all users with their roles, supporting:
  - Search filtering
  - Sorting
  - Pagination
  - Active status filtering
  - Preloading associations
  
  Transforms the results to include the role struct from Roles module.
  """
  def list(opts) do
    User
    |> join(:left, [u], ur in @schema, on: ur.user_id == u.id)
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> hfg_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> filter_active(Map.get(opts, :active))
    |> filter_user(Map.get(opts, :user_id))
    |> Repo.all()
    |> hfg_preload(Map.get(opts, :preload, []))
    #|> Enum.map(&(%{&1 | role: Roles.get(if &1.user_role, do: Map.get(&1.user_role, :role), else: "None")}))
  end

  def list_user_roles(opts) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> hfg_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> filter_active(Map.get(opts, :active))
    |> filter_user_id(Map.get(opts, :user_id))
    |> filter_role_id(Map.get(opts, :role_id))
    |> Repo.all()
    |> hfg_preload(Map.get(opts, :preload, []))
    #|> Enum.map(&(%{&1 | role: Roles.get(if &1.user_role, do: Map.get(&1.user_role, :role), else: "None")}))
  end
end
