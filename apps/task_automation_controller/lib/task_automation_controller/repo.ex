defmodule TaskAutomationController.Repo do
  use Ecto.Repo,
    otp_app: :task_automation_controller,
    adapter: Ecto.Adapters.MyXQL
end
