defmodule HullFamilyGames.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "hull_family_games"
  prefix = case Application.compile_env(:hull_family_games, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "users" do
    field :username,         :string
    field :email,            :string
    field :first_name,       :string
    field :middle_name,      :string
    field :last_name,        :string
    field :active,           :boolean, default: false
    field :portal_admin,     :boolean, default: false
    field :dev_admin,        :boolean, default: false
    field :admin_mode,       :boolean, default: false, virtual: true
    field :test_user,        :boolean, default: false
    field :generic_user,     :boolean, default: false
    field :attempted_login,  :integer, default: 0
    field :password,         :string, virtual: true, redact: true
    field :password_confirm, :string, virtual: true, redact: true
    field :hashed_password,  :string, redact: true
    field :confirmed_at,     :naive_datetime
    field :start_date,       :date
    field :end_date,         :date

    timestamps()
  end

  @doc """
  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.

    * `:validate_username` - Validates the uniqueness of the username, in case
      you don't want to validate the uniqueness of the username (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
  """
  def changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [
      :username, 
      :email, 
      :first_name, 
      :middle_name, 
      :last_name, 
      :active,
      :portal_admin,
      :dev_admin,
      :test_user,
      :generic_user,
      :start_date,
      :end_date,
      :password,
      :password_confirm
    ])
    |> validate_username(opts)
    |> validate_email(opts)
    |> validate_password(opts)
  end

  defp validate_username(changeset, opts) do
    changeset
    |> validate_required([:username])
    |> validate_length(:username, max: 160)
    |> maybe_validate_unique_username(opts)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    #|> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password?   = Keyword.get(opts, :hash_password, true)
    password         = get_change(changeset, :password)
    password_confirm = get_change(changeset, :password_confirm)

    #if hash_password? && password && changeset.valid? do
    #if hash_password? && password && password_confirm && password == password_confirm && changeset.valid? do
    cond do
      hash_password? && password && password_confirm && password == password_confirm && changeset.valid? ->
        changeset
        # If using Bcrypt, then further validate it is at most 72 bytes long
        |> validate_length(:password, max: 72, count: :bytes)
        # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
        # would keep the database transaction open longer and hurt performance.
        |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
        #|> delete_change(:password)

      hash_password? && password && password_confirm && changeset.valid? -> changeset |> add_error(:password, "Passwords do not match")
      hash_password? && password && changeset.valid?                     -> changeset |> add_error(:password, "Please confirm your password")
      true -> changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, HullFamilyGames.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  defp maybe_validate_unique_username(changeset, opts) do
    if Keyword.get(opts, :validate_username, true) do
      changeset
      |> unsafe_validate_unique(:username, HullFamilyGames.Repo)
      |> unique_constraint(:username)
    else
      changeset
    end
  end

  def self_user_changeset(changeset, attrs, opts \\ []) do
    changeset
    |> cast(attrs, [
      :email,
      :first_name,
      :middle_name,
      :last_name,
      :password,
      :password_confirm,
    ])
    |> validate_email(opts)
    |> validate_password(opts)
  end

  def user_changeset(changeset, attrs, opts \\ []) do
    changeset
    |> cast(attrs, [
      :username,
      :email,
      :first_name,
      :middle_name,
      :last_name,
      :active,
      :portal_admin,
      :dev_admin,
      :test_user,
      :generic_user,
      :attempted_login,
      :confirmed_at,
      :start_date,
      :end_date,
      :password,
      :password_confirm,
    ])
    |> validate_email(opts)
    |> validate_password(opts)
    |> unsafe_validate_unique(:username, HullFamilyGames.Repo)
    |> unique_constraint(:username)
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%HullFamilyGames.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
