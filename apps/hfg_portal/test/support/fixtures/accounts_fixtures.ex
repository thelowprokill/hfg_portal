defmodule HfgPortal.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `HfgPortal.Accounts` context.

  Users are created the way an admin adds them: `Accounts.create_or_update/2`.
  """

  alias HfgPortal.Accounts
  alias HfgPortal.Accounts.User

  def unique_username,     do: "user#{System.unique_integer([:positive])}"
  def valid_user_password, do: "hello world!"

  # password_confirm is required for the password to be hashed
  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      username:         unique_username(),
      password:         valid_user_password(),
      password_confirm: valid_user_password(),
      active:           true
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} = Accounts.create_or_update(%User{}, valid_user_attributes(attrs))
    user
  end
end
