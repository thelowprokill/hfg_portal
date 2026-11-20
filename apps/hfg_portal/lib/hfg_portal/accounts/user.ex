defmodule HfgPortal.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "hfg_portal"
  prefix = case Application.compile_env(:hfg_portal, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "users" do
    field :username,         :string
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
    field :start_date,       :date
    field :end_date,         :date

    timestamps()
  end

  @doc """
  The admin changeset: users are only ever added and edited by an admin.

  A user must always have a password: it is required until one is stored (`hashed_password`),
  and must be confirmed (`password_confirm`) to be hashed. Editing a user without one keeps it.

  ## Options

    * `:hash_password` - Hashes the password. Set to `false` for validation only, as in a
      LiveView form. Defaults to `true`.

    * `:validate_username` - Validates the username is unique. Defaults to `true`.
  """
  def changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [
      :username,
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
    |> validate_password(opts)
  end

  defp validate_username(changeset, opts) do
    changeset
    |> validate_required([:username])
    |> validate_length(:username, max: 160)
    |> maybe_validate_unique_username(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> require_password()
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  # no stored password yet (a new user): one must be given
  defp require_password(%{data: %{hashed_password: nil}} = changeset), do: validate_required(changeset, [:password])
  defp require_password(changeset), do: changeset

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

  defp maybe_validate_unique_username(changeset, opts) do
    if Keyword.get(opts, :validate_username, true) do
      changeset
      |> unsafe_validate_unique(:username, HfgPortal.Repo)
      |> unique_constraint(:username)
    else
      changeset
    end
  end

  @doc """
  What users may change about themselves: their name and password, never their access.
  """
  def self_user_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [
      :first_name,
      :middle_name,
      :last_name,
      :password,
      :password_confirm,
    ])
    |> validate_password(opts)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%HfgPortal.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
