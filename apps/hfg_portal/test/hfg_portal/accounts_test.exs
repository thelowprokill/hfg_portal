defmodule HfgPortal.AccountsTest do
  use HfgPortal.DataCase

  alias HfgPortal.Accounts

  import HfgPortal.AccountsFixtures
  alias HfgPortal.Accounts.{User, UserToken}

  # Older than the session validity window.
  @expired ~N[2020-01-01 00:00:00]

  describe "create_or_update/2 (an admin adding or editing a user)" do
    test "creates a user and hashes the confirmed password" do
      {:ok, user} = Accounts.create_or_update(%User{}, valid_user_attributes())
      assert user.hashed_password
      assert User.valid_password?(user, valid_user_password())
    end

    test "a new user must have a password" do
      {:error, changeset} = Accounts.create_or_update(%User{}, %{username: unique_username()})
      assert "can't be blank" in errors_on(changeset).password
    end

    test "the password must be confirmed and match" do
      attrs = valid_user_attributes()

      {:error, changeset} = Accounts.create_or_update(%User{}, Map.delete(attrs, :password_confirm))
      assert "Please confirm your password" in errors_on(changeset).password

      {:error, changeset} = Accounts.create_or_update(%User{}, %{attrs | password_confirm: "something else!"})
      assert "Passwords do not match" in errors_on(changeset).password
    end

    test "validates the password length" do
      {:error, changeset} = Accounts.create_or_update(%User{}, valid_user_attributes(%{password: "short", password_confirm: "short"}))
      assert "should be at least 12 character(s)" in errors_on(changeset).password

      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.create_or_update(%User{}, valid_user_attributes(%{password: too_long, password_confirm: too_long}))
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "requires a unique username" do
      user = user_fixture()

      {:error, changeset} = Accounts.create_or_update(%User{}, valid_user_attributes(%{username: nil}))
      assert "can't be blank" in errors_on(changeset).username

      {:error, changeset} = Accounts.create_or_update(%User{}, valid_user_attributes(%{username: user.username}))
      assert "has already been taken" in errors_on(changeset).username
    end

    test "editing a user keeps their password unless a new one is given" do
      user = user_fixture()

      {:ok, updated} = Accounts.create_or_update(user, %{first_name: "Ada"})
      assert updated.first_name == "Ada"
      assert updated.hashed_password == user.hashed_password

      {:ok, updated} = Accounts.create_or_update(updated, %{password: "a new password", password_confirm: "a new password"})
      assert User.valid_password?(updated, "a new password")
      refute User.valid_password?(updated, valid_user_password())
    end
  end

  describe "update_self_user/2" do
    test "changes the user's name and password" do
      user = user_fixture()
      {:ok, updated} = Accounts.update_self_user(user, %{"first_name" => "Ada", "password" => "a new password", "password_confirm" => "a new password"})
      assert updated.first_name == "Ada"
      assert User.valid_password?(updated, "a new password")
    end

    test "cannot change the user's access" do
      user = user_fixture(%{active: false})
      {:ok, updated} = Accounts.update_self_user(user, %{"portal_admin" => "true", "dev_admin" => "true", "active" => "true", "username" => "admin"})
      assert {updated.portal_admin, updated.dev_admin, updated.active, updated.username} == {false, false, false, user.username}
    end

    test "validates a new password" do
      {:error, changeset} = Accounts.update_self_user(user_fixture(), %{"password" => "short", "password_confirm" => "short"})
      assert "should be at least 12 character(s)" in errors_on(changeset).password
    end
  end

  describe "change_self_user/2" do
    test "only casts the fields a user may change about themselves" do
      changeset = Accounts.change_self_user(user_fixture(), %{first_name: "Ada", portal_admin: true, active: false})
      assert changeset.changes == %{first_name: "Ada"}
    end
  end

  describe "delete_user/1" do
    test "deletes by struct or by id" do
      user = user_fixture()
      assert {:ok, _} = Accounts.delete_user(user)
      refute Repo.get(User, user.id)

      user = user_fixture()
      assert {:ok, _} = Accounts.delete_user(user.id)
      refute Repo.get(User, user.id)
    end
  end

  describe "activate/1 and deactivate/1" do
    test "toggle active" do
      user = user_fixture()
      assert {:ok, %User{active: false}} = Accounts.deactivate(user)
      assert {:ok, %User{active: true}}  = Accounts.activate(user.id)
    end
  end

  describe "get_user_by_username/1 and get_user_by_username_and_password/2" do
    test "find the user by username, and check the password" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_username(user.username)
      assert %User{id: ^id} = Accounts.get_user_by_username_and_password(user.username, valid_user_password())
      refute Accounts.get_user_by_username_and_password(user.username, "invalid")
      refute Accounts.get_user_by_username("unknown")
      refute Accounts.get_user_by_username_and_password("unknown", valid_user_password())
    end
  end

  describe "get_active_user_by_username_and_password/2" do
    test "only returns an active user with the right password" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_active_user_by_username_and_password(user.username, valid_user_password())
      refute Accounts.get_active_user_by_username_and_password(user.username, "invalid")

      {:ok, _} = Accounts.deactivate(user)
      refute Accounts.get_active_user_by_username_and_password(user.username, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises for an unknown id and returns a known one" do
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(-1) end
      %{id: id} = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(id)
    end
  end

  describe "user session tokens" do
    setup do
      user = user_fixture()
      %{user: user, token: Accounts.generate_user_session_token(user)}
    end

    test "generate_user_session_token/1 stores a session token", %{user: user, token: token} do
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
      assert user_token.user_id == user.id
    end

    test "get_user_by_session_token/1 returns the user for a valid token", %{user: user, token: token} do
      assert Accounts.get_user_by_session_token(token).id == user.id
    end

    test "get_user_by_session_token/1 rejects invalid and expired tokens", %{token: token} do
      refute Accounts.get_user_by_session_token("oops")
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: @expired])
      refute Accounts.get_user_by_session_token(token)
    end

    test "delete_user_session_token/1 deletes the token", %{token: token} do
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include the password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
