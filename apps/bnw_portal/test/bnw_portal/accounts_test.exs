defmodule BnwPortal.AccountsTest do
  use BnwPortal.DataCase

  alias BnwPortal.Accounts

  import BnwPortal.AccountsFixtures
  alias BnwPortal.Accounts.{User, UserToken}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users with a hashed password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "change_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_registration(%User{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_user_email()
      password = valid_user_password()

      changeset =
        Accounts.change_user_registration(
          %User{},
          valid_user_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_user_email/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_user_email/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires email to change", %{user: user} do
      {:error, changeset} = Accounts.apply_user_email(user, valid_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_user_email(user, valid_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{user: user} do
      %{email: email} = user_fixture()
      password = valid_user_password()

      {:error, changeset} = Accounts.apply_user_email(user, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_email(user, "invalid", %{email: unique_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{user: user} do
      email = unique_user_email()
      {:ok, user} = Accounts.apply_user_email(user, valid_user_password(), %{email: email})
      assert user.email == email
      assert Accounts.get_user!(user.id).email != email
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "change:current@example.com"
    end
  end

  describe "update_user_email/2" do
    setup do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert Accounts.update_user_email(user, token) == :ok
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      assert changed_user.confirmed_at
      assert changed_user.confirmed_at != user.confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_user_email(user, token) == :error
      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(%User{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, "invalid", %{password: valid_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, _} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "deliver_user_confirmation_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "confirm"
    end
  end

  describe "confirm_user/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_confirmation_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "confirms the email with a valid token", %{user: user, token: token} do
      assert {:ok, confirmed_user} = Accounts.confirm_user(token)
      assert confirmed_user.confirmed_at
      assert confirmed_user.confirmed_at != user.confirmed_at
      assert Repo.get!(User, user.id).confirmed_at
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm with invalid token", %{user: user} do
      assert Accounts.confirm_user("oops") == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not confirm email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_user(token) == :error
      refute Repo.get!(User, user.id).confirmed_at
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "deliver_user_reset_password_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user_token = Repo.get_by(UserToken, token: :crypto.hash(:sha256, token))
      assert user_token.user_id == user.id
      assert user_token.sent_to == user.email
      assert user_token.context == "reset_password"
    end
  end

  describe "get_user_by_reset_password_token/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_reset_password_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "returns the user with valid token", %{user: %{id: id}, token: token} do
      assert %User{id: ^id} = Accounts.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: id)
    end

    test "does not return the user with invalid token", %{user: user} do
      refute Accounts.get_user_by_reset_password_token("oops")
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not return the user if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_reset_password_token(token)
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "reset_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.reset_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_user_password(user, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, updated_user} = Accounts.reset_user_password(user, %{password: "new valid password"})
      assert is_nil(updated_user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)
      {:ok, _} = Accounts.reset_user_password(user, %{password: "new valid password"})
      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  import BnwPortal.AccountsFixtures
  alias BnwPortal.Accounts.{ApiUser, ApiUserToken}

  describe "get_api_user_by_email/1" do
    test "does not return the api_user if the email does not exist" do
      refute Accounts.get_api_user_by_email("unknown@example.com")
    end

    test "returns the api_user if the email exists" do
      %{id: id} = api_user = api_user_fixture()
      assert %ApiUser{id: ^id} = Accounts.get_api_user_by_email(api_user.email)
    end
  end

  describe "get_api_user_by_email_and_password/2" do
    test "does not return the api_user if the email does not exist" do
      refute Accounts.get_api_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the api_user if the password is not valid" do
      api_user = api_user_fixture()
      refute Accounts.get_api_user_by_email_and_password(api_user.email, "invalid")
    end

    test "returns the api_user if the email and password are valid" do
      %{id: id} = api_user = api_user_fixture()

      assert %ApiUser{id: ^id} =
               Accounts.get_api_user_by_email_and_password(api_user.email, valid_api_user_password())
    end
  end

  describe "get_api_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_api_user!(-1)
      end
    end

    test "returns the api_user with the given id" do
      %{id: id} = api_user = api_user_fixture()
      assert %ApiUser{id: ^id} = Accounts.get_api_user!(api_user.id)
    end
  end

  describe "register_api_user/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_api_user(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_api_user(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_api_user(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = api_user_fixture()
      {:error, changeset} = Accounts.register_api_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_api_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers api_users with a hashed password" do
      email = unique_api_user_email()
      {:ok, api_user} = Accounts.register_api_user(valid_api_user_attributes(email: email))
      assert api_user.email == email
      assert is_binary(api_user.hashed_password)
      assert is_nil(api_user.confirmed_at)
      assert is_nil(api_user.password)
    end
  end

  describe "change_api_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_api_user_registration(%ApiUser{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_api_user_email()
      password = valid_api_user_password()

      changeset =
        Accounts.change_api_user_registration(
          %ApiUser{},
          valid_api_user_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_api_user_email/2" do
    test "returns a api_user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_api_user_email(%ApiUser{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_api_user_email/3" do
    setup do
      %{api_user: api_user_fixture()}
    end

    test "requires email to change", %{api_user: api_user} do
      {:error, changeset} = Accounts.apply_api_user_email(api_user, valid_api_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{api_user: api_user} do
      {:error, changeset} =
        Accounts.apply_api_user_email(api_user, valid_api_user_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{api_user: api_user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_api_user_email(api_user, valid_api_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{api_user: api_user} do
      %{email: email} = api_user_fixture()
      password = valid_api_user_password()

      {:error, changeset} = Accounts.apply_api_user_email(api_user, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{api_user: api_user} do
      {:error, changeset} =
        Accounts.apply_api_user_email(api_user, "invalid", %{email: unique_api_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{api_user: api_user} do
      email = unique_api_user_email()
      {:ok, api_user} = Accounts.apply_api_user_email(api_user, valid_api_user_password(), %{email: email})
      assert api_user.email == email
      assert Accounts.get_api_user!(api_user.id).email != email
    end
  end

  describe "deliver_api_user_update_email_instructions/3" do
    setup do
      %{api_user: api_user_fixture()}
    end

    test "sends token through notification", %{api_user: api_user} do
      token =
        extract_api_user_token(fn url ->
          Accounts.deliver_api_user_update_email_instructions(api_user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert api_user_token = Repo.get_by(ApiUserToken, token: :crypto.hash(:sha256, token))
      assert api_user_token.api_user_id == api_user.id
      assert api_user_token.sent_to == api_user.email
      assert api_user_token.context == "change:current@example.com"
    end
  end

  describe "update_api_user_email/2" do
    setup do
      api_user = api_user_fixture()
      email = unique_api_user_email()

      token =
        extract_api_user_token(fn url ->
          Accounts.deliver_api_user_update_email_instructions(%{api_user | email: email}, api_user.email, url)
        end)

      %{api_user: api_user, token: token, email: email}
    end

    test "updates the email with a valid token", %{api_user: api_user, token: token, email: email} do
      assert Accounts.update_api_user_email(api_user, token) == :ok
      changed_api_user = Repo.get!(ApiUser, api_user.id)
      assert changed_api_user.email != api_user.email
      assert changed_api_user.email == email
      assert changed_api_user.confirmed_at
      assert changed_api_user.confirmed_at != api_user.confirmed_at
      refute Repo.get_by(ApiUserToken, api_user_id: api_user.id)
    end

    test "does not update email with invalid token", %{api_user: api_user} do
      assert Accounts.update_api_user_email(api_user, "oops") == :error
      assert Repo.get!(ApiUser, api_user.id).email == api_user.email
      assert Repo.get_by(ApiUserToken, api_user_id: api_user.id)
    end

    test "does not update email if api_user email changed", %{api_user: api_user, token: token} do
      assert Accounts.update_api_user_email(%{api_user | email: "current@example.com"}, token) == :error
      assert Repo.get!(ApiUser, api_user.id).email == api_user.email
      assert Repo.get_by(ApiUserToken, api_user_id: api_user.id)
    end

    test "does not update email if token expired", %{api_user: api_user, token: token} do
      {1, nil} = Repo.update_all(ApiUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_api_user_email(api_user, token) == :error
      assert Repo.get!(ApiUser, api_user.id).email == api_user.email
      assert Repo.get_by(ApiUserToken, api_user_id: api_user.id)
    end
  end

  describe "change_api_user_password/2" do
    test "returns a api_user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_api_user_password(%ApiUser{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_api_user_password(%ApiUser{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_api_user_password/3" do
    setup do
      %{api_user: api_user_fixture()}
    end

    test "validates password", %{api_user: api_user} do
      {:error, changeset} =
        Accounts.update_api_user_password(api_user, valid_api_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{api_user: api_user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_api_user_password(api_user, valid_api_user_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{api_user: api_user} do
      {:error, changeset} =
        Accounts.update_api_user_password(api_user, "invalid", %{password: valid_api_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{api_user: api_user} do
      {:ok, api_user} =
        Accounts.update_api_user_password(api_user, valid_api_user_password(), %{
          password: "new valid password"
        })

      assert is_nil(api_user.password)
      assert Accounts.get_api_user_by_email_and_password(api_user.email, "new valid password")
    end

    test "deletes all tokens for the given api_user", %{api_user: api_user} do
      _ = Accounts.generate_api_user_session_token(api_user)

      {:ok, _} =
        Accounts.update_api_user_password(api_user, valid_api_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(ApiUserToken, api_user_id: api_user.id)
    end
  end

  describe "generate_api_user_session_token/1" do
    setup do
      %{api_user: api_user_fixture()}
    end

    test "generates a token", %{api_user: api_user} do
      token = Accounts.generate_api_user_session_token(api_user)
      assert api_user_token = Repo.get_by(ApiUserToken, token: token)
      assert api_user_token.context == "session"

      # Creating the same token for another api_user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%ApiUserToken{
          token: api_user_token.token,
          api_user_id: api_user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_api_user_by_session_token/1" do
    setup do
      api_user = api_user_fixture()
      token = Accounts.generate_api_user_session_token(api_user)
      %{api_user: api_user, token: token}
    end

    test "returns api_user by token", %{api_user: api_user, token: token} do
      assert session_api_user = Accounts.get_api_user_by_session_token(token)
      assert session_api_user.id == api_user.id
    end

    test "does not return api_user for invalid token" do
      refute Accounts.get_api_user_by_session_token("oops")
    end

    test "does not return api_user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(ApiUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_api_user_by_session_token(token)
    end
  end

  describe "delete_api_user_session_token/1" do
    test "deletes the token" do
      api_user = api_user_fixture()
      token = Accounts.generate_api_user_session_token(api_user)
      assert Accounts.delete_api_user_session_token(token) == :ok
      refute Accounts.get_api_user_by_session_token(token)
    end
  end

  describe "deliver_api_user_confirmation_instructions/2" do
    setup do
      %{api_user: api_user_fixture()}
    end

    test "sends token through notification", %{api_user: api_user} do
      token =
        extract_api_user_token(fn url ->
          Accounts.deliver_api_user_confirmation_instructions(api_user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert api_user_token = Repo.get_by(ApiUserToken, token: :crypto.hash(:sha256, token))
      assert api_user_token.api_user_id == api_user.id
      assert api_user_token.sent_to == api_user.email
      assert api_user_token.context == "confirm"
    end
  end

  describe "confirm_api_user/1" do
    setup do
      api_user = api_user_fixture()

      token =
        extract_api_user_token(fn url ->
          Accounts.deliver_api_user_confirmation_instructions(api_user, url)
        end)

      %{api_user: api_user, token: token}
    end

    test "confirms the email with a valid token", %{api_user: api_user, token: token} do
      assert {:ok, confirmed_api_user} = Accounts.confirm_api_user(token)
      assert confirmed_api_user.confirmed_at
      assert confirmed_api_user.confirmed_at != api_user.confirmed_at
      assert Repo.get!(ApiUser, api_user.id).confirmed_at
      refute Repo.get_by(ApiUserToken, api_user_id: api_user.id)
    end

    test "does not confirm with invalid token", %{api_user: api_user} do
      assert Accounts.confirm_api_user("oops") == :error
      refute Repo.get!(ApiUser, api_user.id).confirmed_at
      assert Repo.get_by(ApiUserToken, api_user_id: api_user.id)
    end

    test "does not confirm email if token expired", %{api_user: api_user, token: token} do
      {1, nil} = Repo.update_all(ApiUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_api_user(token) == :error
      refute Repo.get!(ApiUser, api_user.id).confirmed_at
      assert Repo.get_by(ApiUserToken, api_user_id: api_user.id)
    end
  end

  describe "deliver_api_user_reset_password_instructions/2" do
    setup do
      %{api_user: api_user_fixture()}
    end

    test "sends token through notification", %{api_user: api_user} do
      token =
        extract_api_user_token(fn url ->
          Accounts.deliver_api_user_reset_password_instructions(api_user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert api_user_token = Repo.get_by(ApiUserToken, token: :crypto.hash(:sha256, token))
      assert api_user_token.api_user_id == api_user.id
      assert api_user_token.sent_to == api_user.email
      assert api_user_token.context == "reset_password"
    end
  end

  describe "get_api_user_by_reset_password_token/1" do
    setup do
      api_user = api_user_fixture()

      token =
        extract_api_user_token(fn url ->
          Accounts.deliver_api_user_reset_password_instructions(api_user, url)
        end)

      %{api_user: api_user, token: token}
    end

    test "returns the api_user with valid token", %{api_user: %{id: id}, token: token} do
      assert %ApiUser{id: ^id} = Accounts.get_api_user_by_reset_password_token(token)
      assert Repo.get_by(ApiUserToken, api_user_id: id)
    end

    test "does not return the api_user with invalid token", %{api_user: api_user} do
      refute Accounts.get_api_user_by_reset_password_token("oops")
      assert Repo.get_by(ApiUserToken, api_user_id: api_user.id)
    end

    test "does not return the api_user if token expired", %{api_user: api_user, token: token} do
      {1, nil} = Repo.update_all(ApiUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_api_user_by_reset_password_token(token)
      assert Repo.get_by(ApiUserToken, api_user_id: api_user.id)
    end
  end

  describe "reset_api_user_password/2" do
    setup do
      %{api_user: api_user_fixture()}
    end

    test "validates password", %{api_user: api_user} do
      {:error, changeset} =
        Accounts.reset_api_user_password(api_user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{api_user: api_user} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_api_user_password(api_user, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{api_user: api_user} do
      {:ok, updated_api_user} = Accounts.reset_api_user_password(api_user, %{password: "new valid password"})
      assert is_nil(updated_api_user.password)
      assert Accounts.get_api_user_by_email_and_password(api_user.email, "new valid password")
    end

    test "deletes all tokens for the given api_user", %{api_user: api_user} do
      _ = Accounts.generate_api_user_session_token(api_user)
      {:ok, _} = Accounts.reset_api_user_password(api_user, %{password: "new valid password"})
      refute Repo.get_by(ApiUserToken, api_user_id: api_user.id)
    end
  end

  describe "inspect/2 for the ApiUser module" do
    test "does not include password" do
      refute inspect(%ApiUser{password: "123456"}) =~ "password: \"123456\""
    end
  end

  import BnwPortal.AccountsFixtures
  alias BnwPortal.Accounts.{Customer, CustomerToken}

  describe "get_customer_by_email/1" do
    test "does not return the customer if the email does not exist" do
      refute Accounts.get_customer_by_email("unknown@example.com")
    end

    test "returns the customer if the email exists" do
      %{id: id} = customer = customer_fixture()
      assert %Customer{id: ^id} = Accounts.get_customer_by_email(customer.email)
    end
  end

  describe "get_customer_by_email_and_password/2" do
    test "does not return the customer if the email does not exist" do
      refute Accounts.get_customer_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the customer if the password is not valid" do
      customer = customer_fixture()
      refute Accounts.get_customer_by_email_and_password(customer.email, "invalid")
    end

    test "returns the customer if the email and password are valid" do
      %{id: id} = customer = customer_fixture()

      assert %Customer{id: ^id} =
               Accounts.get_customer_by_email_and_password(customer.email, valid_customer_password())
    end
  end

  describe "get_customer!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_customer!(-1)
      end
    end

    test "returns the customer with the given id" do
      %{id: id} = customer = customer_fixture()
      assert %Customer{id: ^id} = Accounts.get_customer!(customer.id)
    end
  end

  describe "register_customer/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_customer(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_customer(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_customer(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = customer_fixture()
      {:error, changeset} = Accounts.register_customer(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_customer(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers customers with a hashed password" do
      email = unique_customer_email()
      {:ok, customer} = Accounts.register_customer(valid_customer_attributes(email: email))
      assert customer.email == email
      assert is_binary(customer.hashed_password)
      assert is_nil(customer.confirmed_at)
      assert is_nil(customer.password)
    end
  end

  describe "change_customer_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_customer_registration(%Customer{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_customer_email()
      password = valid_customer_password()

      changeset =
        Accounts.change_customer_registration(
          %Customer{},
          valid_customer_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_customer_email/2" do
    test "returns a customer changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_customer_email(%Customer{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_customer_email/3" do
    setup do
      %{customer: customer_fixture()}
    end

    test "requires email to change", %{customer: customer} do
      {:error, changeset} = Accounts.apply_customer_email(customer, valid_customer_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{customer: customer} do
      {:error, changeset} =
        Accounts.apply_customer_email(customer, valid_customer_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{customer: customer} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_customer_email(customer, valid_customer_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{customer: customer} do
      %{email: email} = customer_fixture()
      password = valid_customer_password()

      {:error, changeset} = Accounts.apply_customer_email(customer, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{customer: customer} do
      {:error, changeset} =
        Accounts.apply_customer_email(customer, "invalid", %{email: unique_customer_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{customer: customer} do
      email = unique_customer_email()
      {:ok, customer} = Accounts.apply_customer_email(customer, valid_customer_password(), %{email: email})
      assert customer.email == email
      assert Accounts.get_customer!(customer.id).email != email
    end
  end

  describe "deliver_customer_update_email_instructions/3" do
    setup do
      %{customer: customer_fixture()}
    end

    test "sends token through notification", %{customer: customer} do
      token =
        extract_customer_token(fn url ->
          Accounts.deliver_customer_update_email_instructions(customer, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert customer_token = Repo.get_by(CustomerToken, token: :crypto.hash(:sha256, token))
      assert customer_token.customer_id == customer.id
      assert customer_token.sent_to == customer.email
      assert customer_token.context == "change:current@example.com"
    end
  end

  describe "update_customer_email/2" do
    setup do
      customer = customer_fixture()
      email = unique_customer_email()

      token =
        extract_customer_token(fn url ->
          Accounts.deliver_customer_update_email_instructions(%{customer | email: email}, customer.email, url)
        end)

      %{customer: customer, token: token, email: email}
    end

    test "updates the email with a valid token", %{customer: customer, token: token, email: email} do
      assert Accounts.update_customer_email(customer, token) == :ok
      changed_customer = Repo.get!(Customer, customer.id)
      assert changed_customer.email != customer.email
      assert changed_customer.email == email
      assert changed_customer.confirmed_at
      assert changed_customer.confirmed_at != customer.confirmed_at
      refute Repo.get_by(CustomerToken, customer_id: customer.id)
    end

    test "does not update email with invalid token", %{customer: customer} do
      assert Accounts.update_customer_email(customer, "oops") == :error
      assert Repo.get!(Customer, customer.id).email == customer.email
      assert Repo.get_by(CustomerToken, customer_id: customer.id)
    end

    test "does not update email if customer email changed", %{customer: customer, token: token} do
      assert Accounts.update_customer_email(%{customer | email: "current@example.com"}, token) == :error
      assert Repo.get!(Customer, customer.id).email == customer.email
      assert Repo.get_by(CustomerToken, customer_id: customer.id)
    end

    test "does not update email if token expired", %{customer: customer, token: token} do
      {1, nil} = Repo.update_all(CustomerToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_customer_email(customer, token) == :error
      assert Repo.get!(Customer, customer.id).email == customer.email
      assert Repo.get_by(CustomerToken, customer_id: customer.id)
    end
  end

  describe "change_customer_password/2" do
    test "returns a customer changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_customer_password(%Customer{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_customer_password(%Customer{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_customer_password/3" do
    setup do
      %{customer: customer_fixture()}
    end

    test "validates password", %{customer: customer} do
      {:error, changeset} =
        Accounts.update_customer_password(customer, valid_customer_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{customer: customer} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_customer_password(customer, valid_customer_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{customer: customer} do
      {:error, changeset} =
        Accounts.update_customer_password(customer, "invalid", %{password: valid_customer_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{customer: customer} do
      {:ok, customer} =
        Accounts.update_customer_password(customer, valid_customer_password(), %{
          password: "new valid password"
        })

      assert is_nil(customer.password)
      assert Accounts.get_customer_by_email_and_password(customer.email, "new valid password")
    end

    test "deletes all tokens for the given customer", %{customer: customer} do
      _ = Accounts.generate_customer_session_token(customer)

      {:ok, _} =
        Accounts.update_customer_password(customer, valid_customer_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(CustomerToken, customer_id: customer.id)
    end
  end

  describe "generate_customer_session_token/1" do
    setup do
      %{customer: customer_fixture()}
    end

    test "generates a token", %{customer: customer} do
      token = Accounts.generate_customer_session_token(customer)
      assert customer_token = Repo.get_by(CustomerToken, token: token)
      assert customer_token.context == "session"

      # Creating the same token for another customer should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%CustomerToken{
          token: customer_token.token,
          customer_id: customer_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_customer_by_session_token/1" do
    setup do
      customer = customer_fixture()
      token = Accounts.generate_customer_session_token(customer)
      %{customer: customer, token: token}
    end

    test "returns customer by token", %{customer: customer, token: token} do
      assert session_customer = Accounts.get_customer_by_session_token(token)
      assert session_customer.id == customer.id
    end

    test "does not return customer for invalid token" do
      refute Accounts.get_customer_by_session_token("oops")
    end

    test "does not return customer for expired token", %{token: token} do
      {1, nil} = Repo.update_all(CustomerToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_customer_by_session_token(token)
    end
  end

  describe "delete_customer_session_token/1" do
    test "deletes the token" do
      customer = customer_fixture()
      token = Accounts.generate_customer_session_token(customer)
      assert Accounts.delete_customer_session_token(token) == :ok
      refute Accounts.get_customer_by_session_token(token)
    end
  end

  describe "deliver_customer_confirmation_instructions/2" do
    setup do
      %{customer: customer_fixture()}
    end

    test "sends token through notification", %{customer: customer} do
      token =
        extract_customer_token(fn url ->
          Accounts.deliver_customer_confirmation_instructions(customer, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert customer_token = Repo.get_by(CustomerToken, token: :crypto.hash(:sha256, token))
      assert customer_token.customer_id == customer.id
      assert customer_token.sent_to == customer.email
      assert customer_token.context == "confirm"
    end
  end

  describe "confirm_customer/1" do
    setup do
      customer = customer_fixture()

      token =
        extract_customer_token(fn url ->
          Accounts.deliver_customer_confirmation_instructions(customer, url)
        end)

      %{customer: customer, token: token}
    end

    test "confirms the email with a valid token", %{customer: customer, token: token} do
      assert {:ok, confirmed_customer} = Accounts.confirm_customer(token)
      assert confirmed_customer.confirmed_at
      assert confirmed_customer.confirmed_at != customer.confirmed_at
      assert Repo.get!(Customer, customer.id).confirmed_at
      refute Repo.get_by(CustomerToken, customer_id: customer.id)
    end

    test "does not confirm with invalid token", %{customer: customer} do
      assert Accounts.confirm_customer("oops") == :error
      refute Repo.get!(Customer, customer.id).confirmed_at
      assert Repo.get_by(CustomerToken, customer_id: customer.id)
    end

    test "does not confirm email if token expired", %{customer: customer, token: token} do
      {1, nil} = Repo.update_all(CustomerToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_customer(token) == :error
      refute Repo.get!(Customer, customer.id).confirmed_at
      assert Repo.get_by(CustomerToken, customer_id: customer.id)
    end
  end

  describe "deliver_customer_reset_password_instructions/2" do
    setup do
      %{customer: customer_fixture()}
    end

    test "sends token through notification", %{customer: customer} do
      token =
        extract_customer_token(fn url ->
          Accounts.deliver_customer_reset_password_instructions(customer, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert customer_token = Repo.get_by(CustomerToken, token: :crypto.hash(:sha256, token))
      assert customer_token.customer_id == customer.id
      assert customer_token.sent_to == customer.email
      assert customer_token.context == "reset_password"
    end
  end

  describe "get_customer_by_reset_password_token/1" do
    setup do
      customer = customer_fixture()

      token =
        extract_customer_token(fn url ->
          Accounts.deliver_customer_reset_password_instructions(customer, url)
        end)

      %{customer: customer, token: token}
    end

    test "returns the customer with valid token", %{customer: %{id: id}, token: token} do
      assert %Customer{id: ^id} = Accounts.get_customer_by_reset_password_token(token)
      assert Repo.get_by(CustomerToken, customer_id: id)
    end

    test "does not return the customer with invalid token", %{customer: customer} do
      refute Accounts.get_customer_by_reset_password_token("oops")
      assert Repo.get_by(CustomerToken, customer_id: customer.id)
    end

    test "does not return the customer if token expired", %{customer: customer, token: token} do
      {1, nil} = Repo.update_all(CustomerToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_customer_by_reset_password_token(token)
      assert Repo.get_by(CustomerToken, customer_id: customer.id)
    end
  end

  describe "reset_customer_password/2" do
    setup do
      %{customer: customer_fixture()}
    end

    test "validates password", %{customer: customer} do
      {:error, changeset} =
        Accounts.reset_customer_password(customer, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{customer: customer} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_customer_password(customer, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{customer: customer} do
      {:ok, updated_customer} = Accounts.reset_customer_password(customer, %{password: "new valid password"})
      assert is_nil(updated_customer.password)
      assert Accounts.get_customer_by_email_and_password(customer.email, "new valid password")
    end

    test "deletes all tokens for the given customer", %{customer: customer} do
      _ = Accounts.generate_customer_session_token(customer)
      {:ok, _} = Accounts.reset_customer_password(customer, %{password: "new valid password"})
      refute Repo.get_by(CustomerToken, customer_id: customer.id)
    end
  end

  describe "inspect/2 for the Customer module" do
    test "does not include password" do
      refute inspect(%Customer{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
