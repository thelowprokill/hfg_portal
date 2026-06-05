defmodule HfgPortal.Helpers.DefaultAuthorize do
  @moduledoc """
  Provides a standardized set of authorization operations for role-based access control.
  This macro can be used by any module that needs to implement authorization checks.
  
  Required options:
    - :roles      - The roles module to use
    - :user       - The user struct to use
    - :user_role  - The user role struct to use
    - :user_roles - The user roles module to use
    - :pages      - The pages to use

  ## Example Usage

      use HfgPortal.Helpers.DefaultAuthorize,
        roles:      MyApp.Users.Roles,
        user:       MyApp.Users.User,
        user_role:  MyApp.Users.UserRole,
        user_roles: MyApp.Users.UserRoles,
        pages:      @pages
  """

  defmacro __using__(opts) do
    quote do
      # Module attributes from the options
      @roles      unquote(opts[:roles])
      @user       unquote(opts[:user])
      @user_role  unquote(opts[:user_role])
      @user_roles unquote(opts[:user_roles])
      @pages      unquote(opts[:pages])

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
      defp filter_pages(pages, user_role, dev_admin, authorize) do
        pages
        |> Enum.map(fn page ->
          cond do
            length(Map.get(page, :links, [])) > 0 || is_nil(Map.get(page, :module)) -> Map.put(page, :links, filter_pages(page.links, user_role, dev_admin, authorize))
            true -> page
          end
        end)
        |> Enum.filter(fn page ->
          cond do
            length(Map.get(page, :links, [])) > 0 || is_nil(Map.get(page, :module)) -> length(page.links) > 0
            true -> authorize.(user_role.role, page.id, dev_admin)
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
      def list_pages(%@user{} = user, _),                          do: list_pages(user.user_role, user.dev_admin && user.admin_mode)
      def list_pages(%HfgPortal.Accounts.User{} = user, _),        do: list_pages(user.id, user.dev_admin && user.admin_mode)
      def list_pages(user_id, dev_admin) when is_integer(user_id), do: @user_roles.get(user_id, :user) |> list_pages(dev_admin)
      def list_pages(%@user_role{} = user_role, dev_admin),        do: @pages |> filter_pages(user_role, dev_admin, &authorize/3)

      def list_pages(_, true),  do: @pages
      def list_pages(_, false), do: []

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
      def authorize(%@user{} = user, page, _dev_admin),          do: authorize((if Map.get(user, :user_role), do: user.user_role.role, else: "None"), page, user.dev_admin)
      def authorize(role, page, dev_admin) when is_binary(role), do: authorize(@roles.get(role), page, dev_admin)
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
      def user_authorize(%@roles{} = role, page, dev_admin) do
        cond do
          dev_admin -> true
          role && role.admin && page not in ["reports",] -> true
          role && role.edit  && page     in ["home",] -> true
          role && role.view  && page     in ["home",] -> true
          true -> false
        end
      end
      
      # Allow modules to override any of these functions
      defoverridable [
        filter_pages:   4,
        list_pages:     2,
        authorize:      3,
        user_authorize: 3,
      ]
    end
  end
end
