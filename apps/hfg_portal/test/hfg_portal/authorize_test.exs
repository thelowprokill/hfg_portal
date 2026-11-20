defmodule HfgPortal.AuthorizeTest do
  use HfgPortal.DataCase

  import HfgPortal.AccountsFixtures
  alias HfgPortal.Authorize

  describe "list_pages/2" do
    test "an ordinary user sees nothing" do
      assert Authorize.list_pages(user_fixture()) == []
    end

    test "a dev or portal admin sees the pages only in admin mode" do
      for flag <- [:dev_admin, :portal_admin] do
        user = user_fixture(%{flag => true})
        assert Authorize.list_pages(user) == []
        assert Enum.map(Authorize.list_pages(%{user | admin_mode: true}), & &1.id) == ["home"]
      end
    end

    test "admin mode alone grants nothing" do
      assert Authorize.list_pages(%{user_fixture() | admin_mode: true}) == []
    end

    test "by user id loads the user; admin_mode is never stored so it is always off" do
      user = user_fixture(%{dev_admin: true})
      assert Authorize.list_pages(user.id) == []
    end

    test "anything else gets every page only with dev_admin" do
      assert Enum.map(Authorize.list_pages(nil, true), & &1.id) == ["home"]
      assert Authorize.list_pages(nil) == []
      assert Authorize.list_pages("someone", false) == []
    end
  end

  describe "authorize/3" do
    test "only the dev_admin argument grants access, whatever the user's flags" do
      admin = user_fixture(%{dev_admin: true, portal_admin: true})
      refute Authorize.authorize(admin, "home")
      assert Authorize.authorize(admin, "home", true)
      assert Authorize.authorize(user_fixture(), "anything", true)
    end

    test "non-users are always denied" do
      refute Authorize.authorize(nil, "home", true)
      refute Authorize.authorize(%{dev_admin: true}, "home", true)
    end
  end
end
