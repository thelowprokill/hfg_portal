defmodule HfgPortal.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `HfgPortal.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> HfgPortal.Accounts.register_user()

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def unique_api_user_email, do: "api_user#{System.unique_integer()}@example.com"
  def valid_api_user_password, do: "hello world!"

  def valid_api_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_api_user_email(),
      password: valid_api_user_password()
    })
  end

  def api_user_fixture(attrs \\ %{}) do
    {:ok, api_user} =
      attrs
      |> valid_api_user_attributes()
      |> HfgPortal.Accounts.register_api_user()

    api_user
  end

  def extract_api_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def unique_customer_email, do: "customer#{System.unique_integer()}@example.com"
  def valid_customer_password, do: "hello world!"

  def valid_customer_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_customer_email(),
      password: valid_customer_password()
    })
  end

  def customer_fixture(attrs \\ %{}) do
    {:ok, customer} =
      attrs
      |> valid_customer_attributes()
      |> HfgPortal.Accounts.register_customer()

    customer
  end

  def extract_customer_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
