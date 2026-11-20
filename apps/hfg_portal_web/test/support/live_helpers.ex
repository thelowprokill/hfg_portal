defmodule HfgPortalWeb.LiveHelpers do
  @moduledoc """
  Helpers for LiveView tests. Every page is a child LiveView rendered by
  `HfgPortalWeb.Layout.SidebarLive` at `/?page=app,page`.
  """
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint HfgPortalWeb.Endpoint

  @doc "Mounts `/?page=<page><extra>` and returns `{sidebar, page}` views."
  def open_page(conn, page, extra \\ "") do
    {:ok, view, _html} = live(conn, "/?page=#{page}#{extra}")
    {view, find_live_child(view, "root")}
  end

  @doc "Mounts the page and returns the module the sidebar actually rendered for it."
  def rendered_module(conn, page, extra \\ "") do
    {_view, child} = open_page(conn, page, extra)
    child.module
  end

  def log_in(conn, user), do: HfgPortalWeb.ConnCase.log_in_user(conn, user)

  ## App roles

  def budget_role(user, role),
    do: {:ok, _} = Budget.UserRoles.create_or_update(%Budget.Users.UserRole{}, %{user_id: user.id, role: role})

  def homm_role(user, role),
    do: {:ok, _} = HommSaves.UserRoles.create_or_update(%HommSaves.Users.UserRole{}, %{user_id: user.id, role: role})

  @doc "Creates a Task Automation role (admin or not) and gives it to the user."
  def tac_role(user, opts \\ []) do
    {:ok, role} =
      TaskAutomationController.Roles.create_or_update(
        %TaskAutomationController.Users.Role{admin: Keyword.get(opts, :admin, false)},
        %{name: "role#{System.unique_integer([:positive])}", active: true}
      )

    {:ok, _} =
      TaskAutomationController.UserRoles.create_or_update(
        %TaskAutomationController.Users.UserRole{},
        %{user_id: user.id, role_id: role.id, active: true}
      )

    role
  end
end
