defmodule HfgPortal.Accounts.ApiUserNotifier do
  import Swoosh.Email

  alias HfgPortal.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"HfgPortal", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(api_user, url) do
    deliver(api_user.email, "Confirmation instructions", """

    ==============================

    Hi #{api_user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a api_user password.
  """
  def deliver_reset_password_instructions(api_user, url) do
    deliver(api_user.email, "Reset password instructions", """

    ==============================

    Hi #{api_user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a api_user email.
  """
  def deliver_update_email_instructions(api_user, url) do
    deliver(api_user.email, "Update email instructions", """

    ==============================

    Hi #{api_user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end
end
