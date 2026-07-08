defmodule TaskAutomationController.Authorize do
  @roles      TaskAutomationController.Users.Role
  #@user       TaskAutomationController.Users.User
  @user_role  TaskAutomationController.Users.UserRole
  @user_roles TaskAutomationController.UserRoles

  alias HfgPortal.Helpers.Page

  # This is the list of pages for the app
  # These are the pages that show up in the sidebar
  @pages [
    %Page{id: "home",           name: "Home",           module: HfgPortalWeb.TaskAutomationController.Home.HomeLive},
    %Page{id: "completed_jobs", name: "Completed Jobs", module: HfgPortalWeb.TaskAutomationController.Home.HomeLive},
    %Page{id: "manage",         name: "Manage",         links: [
      %Page{id: "machines",   name: "Machines",   module: HfgPortalWeb.TaskAutomationController.Manage.Machines.MachinesLive},
      %Page{id: "jobs",       name: "Jobs",       module: HfgPortalWeb.TaskAutomationController.Manage.Jobs.JobsLive},
      %Page{id: "priorities", name: "Priorities", module: HfgPortalWeb.TaskAutomationController.Manage.Priorities.PrioritiesLive},
      %Page{id: "roles",      name: "Roles",      module: HfgPortalWeb.TaskAutomationController.Manage.Roles.RolesLive},
      %Page{id: "users",      name: "Users",      module: HfgPortalWeb.TaskAutomationController.Manage.Users.UsersLive},
    ]},
  ]

  #Filters pages based on user role and permissions.
  #
  #Recursively processes the page tree, filtering out pages that the user doesn't have access to.
  #
  ### Parameters
  #  - pages: List of page maps to filter
  #  - user_role: The user's role struct
  #  - dev_admin: Boolean indicating if the user is a developer admin
  #  - authorize: Authorization function to check permissions
  #  
  ### Returns
  #  - Filtered list of pages the user has access to
  defp filter_pages(pages, user_roles, dev_admin, authorize) do
    pages
    |> Enum.map(fn page ->
      cond do
        length(Map.get(page, :links, [])) > 0 || is_nil(Map.get(page, :module)) -> Map.put(page, :links, filter_pages(page.links, user_roles, dev_admin, authorize))
        true -> page
      end
    end)
    |> Enum.filter(fn page ->
      cond do
        length(Map.get(page, :links, [])) > 0 || is_nil(Map.get(page, :module)) -> length(page.links) > 0
        true -> authorize.(user_roles, page.id, dev_admin)
      end
    end)
  end
  
  @doc """
  Lists all pages that a user has access to.
  
  ## Parameters
    - user: User struct, user ID, or user role
    - dev_admin: Boolean indicating if the user is a developer admin (defaults to false)
    
  ## Returns
    - List of pages the user has access to
  """
  def list_pages(user, dev_admin \\ false)
  #def list_pages(%@user{} = user, _),                          do: list_pages(user.user_role, user.dev_admin && user.admin_mode)
  def list_pages(%HfgPortal.Accounts.User{} = user, _),        do: list_pages(user.id, user.dev_admin && user.admin_mode)
  #def list_pages(user_id, dev_admin) when is_integer(user_id), do: @user_roles.get(user_id, :user) |> list_pages(dev_admin)
  def list_pages(user_id, dev_admin) when is_integer(user_id), do: @user_roles.list_user_roles(%{user_id: user_id, preload: [:role]}) |> list_pages(dev_admin)
  def list_pages(user_roles, dev_admin),                       do: @pages |> filter_pages(user_roles, dev_admin, &user_authorize/3)

  #def list_pages(_, true),  do: @pages
  #def list_pages(_, false), do: []

  @doc """
  Checks if a user has authorization to access a specific page.
  
  ## Parameters
    - role: Role struct, user role struct, user struct, or role name
    - page: Page ID to check authorization for
    - dev_admin: Boolean indicating if the user is a developer admin (defaults to false)
    
  ## Returns
    - true if authorized, false otherwise
  """
  def authorize(role, page, dev_admin \\ false)
  def authorize(%@roles{} = role, page, dev_admin),          do: user_authorize(role, page, dev_admin)
  def authorize(%@user_role{} = user_role, page, dev_admin), do: authorize(user_role.role, page, dev_admin)
  #def authorize(%@user{} = user, page, _dev_admin),          do: authorize((if Map.get(user, :user_role), do: user.user_role.role, else: "None"), page, user.dev_admin)
  #def authorize(role, page, dev_admin) when is_binary(role), do: authorize(@roles.get(role), page, dev_admin)
  def authorize(_user, _page, _dev_admin),                   do: false

  @doc """
  Implements the core authorization logic based on role permissions.
  
  ## Parameters
    - role: Role struct
    - page: Page ID to check authorization for
    - dev_admin: Boolean indicating if the user is a developer admin
    
  ## Returns
    - true if authorized, false otherwise
  """
  def user_authorize(roles, page, dev_admin) do
    cond do
      dev_admin -> true
      roles && Enum.any?(roles, &(&1.role.admin)) && page not in ["reports",]               -> true
      roles && length(roles) > 0                  && page     in ["home", "completed_jobs"] -> true
      true -> false
    end
  end
end
