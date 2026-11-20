defmodule HfgPortal.Accounts do
  @moduledoc """
  The Accounts context.

  Users are only added by an admin (`create_or_update/2` from `DefaultCrud`, through
  `User.changeset/3`) and sign in with their username and password.
  """

  @topic "bnwportal:users"
  @schema HfgPortal.Accounts.User
  @updated [:user, :updated]
  @created [:user, :created]
  @deleted [:user, :deleted]

  use HfgPortal.Helpers.DefaultCrud,
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  alias HfgPortal.Accounts.{User, UserToken}

  ## Self service

  def change_self_user(%User{} = user, attrs \\ %{}), do: User.self_user_changeset(user, attrs)

  @doc "Saves a user's changes to themselves: their name and password only."
  def update_self_user(%User{} = user, attrs) do
    user
    |> User.self_user_changeset(attrs)
    |> Repo.update()
    |> notify_subscribers(@updated)
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
    |> notify_subscribers(@deleted)
  end

  def delete_user(id) do
    get_user!(id)
    |> delete_user()
  end

  ## Database getters

  @doc """
  Gets an active user by username and password.

  ## Examples

      iex> get_active_user_by_username_and_password("foo.bar", "correct_password")
      %User{}

      iex> get_active_user_by_username_and_password("foo.bar", "invalid_password")
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
end
