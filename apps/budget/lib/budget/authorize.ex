defmodule Budget.Authorize do
  alias Budget.{
    Admins,
    UserRoles,
    #Roles,
  }
  alias BnwPortal.Helpers.Page

  @pages [
    %Page{id: "home",      name: "Home",      module: BnwPortalWeb.Budget.Home.HomeLive},
    %Page{id: "companies", name: "Companies", module: BnwPortalWeb.Budget.Companies.CompaniesLive},
    %Page{id: "admins",    name: "Admins",    module: BnwPortalWeb.Budget.Admins.AdminsLive},
    %Page{id: "reports",   name: "Reports",   module: BnwPortalWeb.Budget.Reports.ReportsLive},
  ]

  def list_pages(%{dev_admin: true, admin_mode: true}), do: @pages
  # this is temporary so I don't have to have admin mode on all the time
  #def list_pages(%{dev_admin: true}) do
  #  IO.puts ""
  #  IO.puts ""
  #  IO.puts ""
  #  IO.puts "{{{{{{{{{{{{{{{{{{{{{{ Budget.Authorize.list_pages(%{dev_admin: true}) }}}}}}}}}}}}}}}}}}}}}}"
  #  IO.puts "delete me"
  #  IO.puts "{{{{{{{{{{{{{{{{{{{{{{ Budget.Authorize.list_pages(%{dev_admin: true}) }}}}}}}}}}}}}}}}}}}}}}"
  #  IO.puts ""
  #  IO.puts ""
  #  IO.puts ""
  #  @pages
  #  |> Enum.reject(&(&1.id in ["reports"]))
  #end
  def list_pages(user) do 
    %{company_permissions: company_permissions, home_permissions: home_permissions} = UserRoles.fetch_user_permissions(user.id)
    admin = Admins.is_admin(user.id) && user.admin_mode

    @pages
    |> Enum.filter(&(authorize(&1.id, company_permissions, home_permissions, admin)))
  end

  def authorize(page_id, company_permissions \\ [], home_permissions \\ [], admin \\ false)
  def authorize("home",      _, _, true), do: true
  def authorize("companies", _, _, true), do: true
  def authorize("home",      _company_permissions, home_permissions,  _)  when length(home_permissions)    > 0, do: true
  def authorize("companies", company_permissions,  _home_permissions, _) when length(company_permissions) > 0, do: true
  def authorize(_page,       _company_permissions, _home_permissions, _), do: false
end
