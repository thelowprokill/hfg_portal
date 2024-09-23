defmodule HullFamilyGames.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query
  import HullFamilyGames.Helpers.Utility

  alias HullFamilyGames.Repo

  alias HullFamilyGames.Accounts.{
    User,
    UserToken,
    UserNotifier
  }

  @topic "bnwportal:users"

  @schema HullFamilyGames.Accounts.User
  @updated [:user, :updated]
  @created [:user, :created]
  @deleted [:user, :deleted]

  def subscribe(),     do: Phoenix.PubSub.subscribe(HullFamilyGames.PubSub,   @topic)
  def subscribe(id),   do: Phoenix.PubSub.subscribe(HullFamilyGames.PubSub,   "#{@topic}:#{id}")
  def unsubscribe(),   do: Phoenix.PubSub.unsubscribe(HullFamilyGames.PubSub, @topic)
  def unsubscribe(id), do: Phoenix.PubSub.unsubscribe(HullFamilyGames.PubSub, "#{@topic}:#{id}")
  defp notify_subscribers({:ok, result}, event) do
    Phoenix.PubSub.broadcast(HullFamilyGames.PubSub, @topic, {event, result})
    Phoenix.PubSub.broadcast(HullFamilyGames.PubSub, "#{@topic}:#{result.id}", {event, result})
    {:ok, result}
  end
  defp notify_subscribers({:error, reason}, _event), do: {:error, reason}


  defp search_stack(query, search_stack) when is_list(search_stack) do
    Enum.reduce(search_stack, query, fn(search, query) ->
      cond do
        search.field in @schema.__schema__(:fields) -> query |> where([r], like(field(r, ^search.field), ^"%#{search.val}%") or ^search.val == "")
        true -> query
      end
    end)
  end
  defp search_stack(query, nil), do: query

  defp sort_stack(query, sort_stack) when is_list(sort_stack) do
    Enum.reduce(sort_stack, query, fn(sort, query) ->
      cond do
        sort.field in @schema.__schema__(:fields) -> query |> order_by([{^sort.order, ^sort.field}])
        true -> query
      end
    end)
  end
  defp sort_stack(query, nil), do: query

  def filter_active(query, active) when not is_nil(active), do: query |> where(active: ^active)
  def filter_active(query, _active), do: query

  defp filter_budget(query, budget_id) when not is_nil(budget_id), do: where(query, [ba], ba.budget_id == ^budget_id)
  defp filter_budget(query, _budget_id), do: query

  def list(opts \\ %{}) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> bnw_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> filter_active(Map.get(opts, :active))
    |> filter_budget(Map.get(opts, :budget_id))
    |> Repo.all()
    |> bnw_preload(Map.get(opts, :preload, []))
  end
  def preload(val, opts \\ %{}), do: bnw_preload(val, Map.get(opts, :preload, []))

  def create_or_update(%@schema{} = item, attrs \\ %{}) do
    new_item = is_nil(item.id)
    item
    |> change(attrs)
    |> Repo.insert_or_update()
    |> notify_subscribers(if new_item, do: @created, else: @updated)
  end

  def get(id), do: Repo.get(@schema, id)
  def new(), do: %@schema{}
  def new_changeset(attrs \\ %{}), do: new() |> change(attrs)
  def change(%@schema{} = item, attrs \\ %{}), do: @schema.changeset(item, attrs)
  def delete(%@schema{} = item), do: item |> Repo.delete() |> notify_subscribers(@deleted)
  def delete(id), do: get(id) |> delete()

  def activate(item, key \\ :active)
  def activate(%@schema{} = item, key),   do: item |> change(Map.put(%{}, key, true))  |> Repo.update() |> notify_subscribers(@updated)
  def activate(id, key), do: get(id) |> activate(key)

  def deactivate(item, key \\ :active)
  def deactivate(%@schema{} = item, key), do: item |> change(Map.put(%{}, key, false)) |> Repo.update() |> notify_subscribers(@updated)
  def deactivate(id, key), do: get(id) |> deactivate(key)




  def change_self_user(%User{} = user, attrs \\ %{}), do: User.self_user_changeset(user, attrs)
  #def change_user(%User{} = user, attrs \\ %{}), do: User.user_changeset(user, attrs)

  def create_user_with_google_profile(profile \\ %{}) do
    attrs = %{
      active: true,
      username: (profile.email |> String.split("@") |> Enum.at(0)),
      email: profile.email,
      first_name: profile.given_name,
      last_name: profile.family_name,
    }

    %User{}
    |> User.user_changeset(attrs, [validate_username: true])
    |> Repo.insert()
    |> notify_subscribers([:user, :created])
  end

  def create_or_update_user(%User{} = user, attrs \\ %{}) do
    user
    |> User.user_changeset(attrs, [hash_password: true])
    |> Repo.insert_or_update()
    |> notify_subscribers([:user, :updated])
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
    |> notify_subscribers([:user, :deleted])
  end

  def delete_user(id) do
    get_user!(id)
    |> delete_user()
  end

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a active user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_active_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, [email: email, active: true])
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_active_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_active_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_active_user_by_username_and_password(username, password)
      when is_binary(username) and is_binary(password) do
    user = Repo.get_by(User, [username: username, active: true])
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a user by username.

  ## Examples

      iex> get_user_by_username("foo.bar")
      %User{}

      iex> get_user_by_username("unknown")
      nil

  """
  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end

  @doc """
  Gets a user by username and password.

  ## Examples

      iex> get_user_by_username_and_password("foo.bar", "correct_password")
      %User{}

      iex> get_user_by_username_and_password("foo.bar", "invalid_password")
      nil

  """
  def get_user_by_username_and_password(username, password)
      when is_binary(username) and is_binary(password) do
    user = Repo.get_by(User, username: username)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  alias HullFamilyGames.Accounts.{ApiUser, ApiUserToken, ApiUserNotifier}

  ## Database getters

  @doc """
  Gets a api_user by email.

  ## Examples

      iex> get_api_user_by_email("foo@example.com")
      %ApiUser{}

      iex> get_api_user_by_email("unknown@example.com")
      nil

  """
  def get_api_user_by_email(email) when is_binary(email) do
    Repo.get_by(ApiUser, email: email)
  end

  @doc """
  Gets a api_user by email and password.

  ## Examples

      iex> get_api_user_by_email_and_password("foo@example.com", "correct_password")
      %ApiUser{}

      iex> get_api_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_api_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    api_user = Repo.get_by(ApiUser, email: email)
    if ApiUser.valid_password?(api_user, password), do: api_user
  end

  @doc """
  Gets a single api_user.

  Raises `Ecto.NoResultsError` if the ApiUser does not exist.

  ## Examples

      iex> get_api_user!(123)
      %ApiUser{}

      iex> get_api_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_api_user!(id), do: Repo.get!(ApiUser, id)

  ## Api user registration

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking api_user changes.

  ### Examples

  #    iex> change_api_user_registration(api_user)
  #    %Ecto.Changeset{data: %ApiUser{}}

  """
  def change_api_user_registration(%ApiUser{} = api_user, attrs \\ %{}) do
    ApiUser.registration_changeset(api_user, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the api_user email.

  ## Examples

      iex> change_api_user_email(api_user)
      %Ecto.Changeset{data: %ApiUser{}}

  """
  def change_api_user_email(api_user, attrs \\ %{}) do
    ApiUser.email_changeset(api_user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_api_user_email(api_user, "valid password", %{email: ...})
      {:ok, %ApiUser{}}

      iex> apply_api_user_email(api_user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_api_user_email(api_user, password, attrs) do
    api_user
    |> ApiUser.email_changeset(attrs)
    |> ApiUser.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the api_user email using the given token.

  If the token matches, the api_user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_api_user_email(api_user, token) do
    context = "change:#{api_user.email}"

    with {:ok, query} <- ApiUserToken.verify_change_email_token_query(token, context),
         %ApiUserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(api_user_email_multi(api_user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp api_user_email_multi(api_user, email, context) do
    changeset =
      api_user
      |> ApiUser.email_changeset(%{email: email})
      |> ApiUser.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:api_user, changeset)
    |> Ecto.Multi.delete_all(:tokens, ApiUserToken.api_user_and_contexts_query(api_user, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given api_user.

  ## Examples

      iex> deliver_api_user_update_email_instructions(api_user, current_email, &url(~p"/api_users/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_api_user_update_email_instructions(%ApiUser{} = api_user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, api_user_token} = ApiUserToken.build_email_token(api_user, "change:#{current_email}")

    Repo.insert!(api_user_token)
    ApiUserNotifier.deliver_update_email_instructions(api_user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the api_user password.

  ## Examples

      iex> change_api_user_password(api_user)
      %Ecto.Changeset{data: %ApiUser{}}

  """
  def change_api_user_password(api_user, attrs \\ %{}) do
    ApiUser.password_changeset(api_user, attrs, hash_password: false)
  end

  @doc """
  Updates the api_user password.

  ## Examples

      iex> update_api_user_password(api_user, "valid password", %{password: ...})
      {:ok, %ApiUser{}}

      iex> update_api_user_password(api_user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_api_user_password(api_user, password, attrs) do
    changeset =
      api_user
      |> ApiUser.password_changeset(attrs)
      |> ApiUser.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:api_user, changeset)
    |> Ecto.Multi.delete_all(:tokens, ApiUserToken.api_user_and_contexts_query(api_user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{api_user: api_user}} -> {:ok, api_user}
      {:error, :api_user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_api_user_session_token(api_user) do
    {token, api_user_token} = ApiUserToken.build_session_token(api_user)
    Repo.insert!(api_user_token)
    token
  end

  @doc """
  Gets the api_user with the given signed token.
  """
  def get_api_user_by_session_token(token) do
    {:ok, query} = ApiUserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_api_user_session_token(token) do
    Repo.delete_all(ApiUserToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given api_user.

  ## Examples

      iex> deliver_api_user_confirmation_instructions(api_user, &url(~p"/api_users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_api_user_confirmation_instructions(confirmed_api_user, &url(~p"/api_users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_api_user_confirmation_instructions(%ApiUser{} = api_user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if api_user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, api_user_token} = ApiUserToken.build_email_token(api_user, "confirm")
      Repo.insert!(api_user_token)
      ApiUserNotifier.deliver_confirmation_instructions(api_user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a api_user by the given token.

  If the token matches, the api_user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_api_user(token) do
    with {:ok, query} <- ApiUserToken.verify_email_token_query(token, "confirm"),
         %ApiUser{} = api_user <- Repo.one(query),
         {:ok, %{api_user: api_user}} <- Repo.transaction(confirm_api_user_multi(api_user)) do
      {:ok, api_user}
    else
      _ -> :error
    end
  end

  defp confirm_api_user_multi(api_user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:api_user, ApiUser.confirm_changeset(api_user))
    |> Ecto.Multi.delete_all(:tokens, ApiUserToken.api_user_and_contexts_query(api_user, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given api_user.

  ## Examples

      iex> deliver_api_user_reset_password_instructions(api_user, &url(~p"/api_users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_api_user_reset_password_instructions(%ApiUser{} = api_user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, api_user_token} = ApiUserToken.build_email_token(api_user, "reset_password")
    Repo.insert!(api_user_token)
    ApiUserNotifier.deliver_reset_password_instructions(api_user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the api_user by reset password token.

  ## Examples

      iex> get_api_user_by_reset_password_token("validtoken")
      %ApiUser{}

      iex> get_api_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_api_user_by_reset_password_token(token) do
    with {:ok, query} <- ApiUserToken.verify_email_token_query(token, "reset_password"),
         %ApiUser{} = api_user <- Repo.one(query) do
      api_user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the api_user password.

  ## Examples

      iex> reset_api_user_password(api_user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %ApiUser{}}

      iex> reset_api_user_password(api_user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_api_user_password(api_user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:api_user, ApiUser.password_changeset(api_user, attrs))
    |> Ecto.Multi.delete_all(:tokens, ApiUserToken.api_user_and_contexts_query(api_user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{api_user: api_user}} -> {:ok, api_user}
      {:error, :api_user, changeset, _} -> {:error, changeset}
    end
  end

  alias HullFamilyGames.Accounts.{Customer, CustomerToken, CustomerNotifier}

  ## Database getters

  @doc """
  Gets a customer by email.

  ## Examples

      iex> get_customer_by_email("foo@example.com")
      %Customer{}

      iex> get_customer_by_email("unknown@example.com")
      nil

  """
  def get_customer_by_email(email) when is_binary(email) do
    Repo.get_by(Customer, email: email)
  end

  @doc """
  Gets a customer by email and password.

  ## Examples

      iex> get_customer_by_email_and_password("foo@example.com", "correct_password")
      %Customer{}

      iex> get_customer_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_customer_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    customer = Repo.get_by(Customer, email: email)
    if Customer.valid_password?(customer, password), do: customer
  end

  @doc """
  Gets a single customer.

  Raises `Ecto.NoResultsError` if the Customer does not exist.

  ## Examples

      iex> get_customer!(123)
      %Customer{}

      iex> get_customer!(456)
      ** (Ecto.NoResultsError)

  """
  def get_customer!(id), do: Repo.get!(Customer, id)

  ## Customer registration

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking customer changes.

  ### Examples

  #    iex> change_customer_registration(customer)
  #    %Ecto.Changeset{data: %Customer{}}

  """
  def change_customer_registration(%Customer{} = customer, attrs \\ %{}) do
    Customer.registration_changeset(customer, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the customer email.

  ## Examples

      iex> change_customer_email(customer)
      %Ecto.Changeset{data: %Customer{}}

  """
  def change_customer_email(customer, attrs \\ %{}) do
    Customer.email_changeset(customer, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_customer_email(customer, "valid password", %{email: ...})
      {:ok, %Customer{}}

      iex> apply_customer_email(customer, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_customer_email(customer, password, attrs) do
    customer
    |> Customer.email_changeset(attrs)
    |> Customer.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the customer email using the given token.

  If the token matches, the customer email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_customer_email(customer, token) do
    context = "change:#{customer.email}"

    with {:ok, query} <- CustomerToken.verify_change_email_token_query(token, context),
         %CustomerToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(customer_email_multi(customer, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp customer_email_multi(customer, email, context) do
    changeset =
      customer
      |> Customer.email_changeset(%{email: email})
      |> Customer.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:customer, changeset)
    |> Ecto.Multi.delete_all(:tokens, CustomerToken.customer_and_contexts_query(customer, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given customer.

  ## Examples

      iex> deliver_customer_update_email_instructions(customer, current_email, &url(~p"/customers/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_customer_update_email_instructions(%Customer{} = customer, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, customer_token} = CustomerToken.build_email_token(customer, "change:#{current_email}")

    Repo.insert!(customer_token)
    CustomerNotifier.deliver_update_email_instructions(customer, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the customer password.

  ## Examples

      iex> change_customer_password(customer)
      %Ecto.Changeset{data: %Customer{}}

  """
  def change_customer_password(customer, attrs \\ %{}) do
    Customer.password_changeset(customer, attrs, hash_password: false)
  end

  @doc """
  Updates the customer password.

  ## Examples

      iex> update_customer_password(customer, "valid password", %{password: ...})
      {:ok, %Customer{}}

      iex> update_customer_password(customer, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_customer_password(customer, password, attrs) do
    changeset =
      customer
      |> Customer.password_changeset(attrs)
      |> Customer.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:customer, changeset)
    |> Ecto.Multi.delete_all(:tokens, CustomerToken.customer_and_contexts_query(customer, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{customer: customer}} -> {:ok, customer}
      {:error, :customer, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_customer_session_token(customer) do
    {token, customer_token} = CustomerToken.build_session_token(customer)
    Repo.insert!(customer_token)
    token
  end

  @doc """
  Gets the customer with the given signed token.
  """
  def get_customer_by_session_token(token) do
    {:ok, query} = CustomerToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_customer_session_token(token) do
    Repo.delete_all(CustomerToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given customer.

  ## Examples

      iex> deliver_customer_confirmation_instructions(customer, &url(~p"/customers/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_customer_confirmation_instructions(confirmed_customer, &url(~p"/customers/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_customer_confirmation_instructions(%Customer{} = customer, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if customer.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, customer_token} = CustomerToken.build_email_token(customer, "confirm")
      Repo.insert!(customer_token)
      CustomerNotifier.deliver_confirmation_instructions(customer, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a customer by the given token.

  If the token matches, the customer account is marked as confirmed
  and the token is deleted.
  """
  def confirm_customer(token) do
    with {:ok, query} <- CustomerToken.verify_email_token_query(token, "confirm"),
         %Customer{} = customer <- Repo.one(query),
         {:ok, %{customer: customer}} <- Repo.transaction(confirm_customer_multi(customer)) do
      {:ok, customer}
    else
      _ -> :error
    end
  end

  defp confirm_customer_multi(customer) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:customer, Customer.confirm_changeset(customer))
    |> Ecto.Multi.delete_all(:tokens, CustomerToken.customer_and_contexts_query(customer, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given customer.

  ## Examples

      iex> deliver_customer_reset_password_instructions(customer, &url(~p"/customers/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_customer_reset_password_instructions(%Customer{} = customer, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, customer_token} = CustomerToken.build_email_token(customer, "reset_password")
    Repo.insert!(customer_token)
    CustomerNotifier.deliver_reset_password_instructions(customer, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the customer by reset password token.

  ## Examples

      iex> get_customer_by_reset_password_token("validtoken")
      %Customer{}

      iex> get_customer_by_reset_password_token("invalidtoken")
      nil

  """
  def get_customer_by_reset_password_token(token) do
    with {:ok, query} <- CustomerToken.verify_email_token_query(token, "reset_password"),
         %Customer{} = customer <- Repo.one(query) do
      customer
    else
      _ -> nil
    end
  end

  @doc """
  Resets the customer password.

  ## Examples

      iex> reset_customer_password(customer, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %Customer{}}

      iex> reset_customer_password(customer, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_customer_password(customer, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:customer, Customer.password_changeset(customer, attrs))
    |> Ecto.Multi.delete_all(:tokens, CustomerToken.customer_and_contexts_query(customer, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{customer: customer}} -> {:ok, customer}
      {:error, :customer, changeset, _} -> {:error, changeset}
    end
  end
end
