defmodule HfgPortalWeb.TaskAutomationController.Home.Modals.AddJob do
  use HfgPortalWeb, :live_component

  alias TaskAutomationController.{
    Jobs,
  }

  @module TaskAutomationController.QueuedItems
  @key "queue"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="new_job_modal">
        <.bnw_modal_header>New Job</.bnw_modal_header>
        <.form :let={f}
          for={@modal.changeset}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save">
          <.bnw_modal_body>

            <%= if is_nil(@modal.changeset.data.id) do %>
              <.bnw_input_hidden f={f} field={:created_by_id} value={@modal.user.id} />
            <% end %>
            <.bnw_input_hidden f={f} field={:updated_by_id} value={@modal.user.id} />

            <.bnw_input f={f} field={:job_id} display_name="Job" type="select" list={@jobs} />

          </.bnw_modal_body>
          <.bnw_modal_footer><.bnw_button_cancel /><.bnw_button_submit/></.bnw_modal_footer>
        </.form>
      </.bnw_modal>
    </div>
    """
  end

  defp fetch_jobs(socket) do 
    %{modal: %{user: %{id: user_id, dev_admin: dev_admin, admin_mode: admin_mode}}} = socket.assigns

    jobs = cond do
      dev_admin && admin_mode -> Jobs.list()
      true -> Jobs.list(%{user_id: user_id})
    end
    |> Enum.map(&([key: &1.name, value: &1.id]))

    socket 
    |> assign(:jobs, jobs)
  end

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> fetch_jobs()
    |> res(:ok)
  end

  defp save(socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns

    cond do
      changeset.valid? ->
        changeset.data |> @module.create_or_update(changeset.changes)
        |> case do
          {:ok, _} -> socket |> cancel()
          {:error, changeset} ->
            socket |> assign(:modal, %{modal | changeset: changeset})
        end
      true -> socket
    end
  end

  defp cancel(socket) do
    #%{parent: parent} = socket.assigns
    send(self(), :cancel)
    socket
  end

  @impl true
  def handle_event("validate", params, socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns

    params = params |> Map.get(@key, %{})

    changeset =
      changeset.data
      |> @module.change(params)
      |> Map.put(:action, :insert)

    socket
    |> assign(:modal, %{modal | changeset: changeset})
    |> res()
  end

  @impl true
  def handle_event("save", params, socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns

    params = params |> IO.inspect |> Map.get(@key, %{})

    #job = Map.get(params, "job_id") |> String.to_integer() |> Jobs.get() |> Jobs.preload(%{preload: [:priority]})

    params = %{
      job_id:        Map.get(params, "job_id"),
      status:        "unassigned",
      type:          "user",
      user_id:       modal.user.id,
      created_by_id: modal.user.id,
      updated_by_id: modal.user.id,
      active:        true,
    }

    changeset =
      changeset.data
      |> @module.change(params)
      |> Map.put(:action, :insert)

    socket
    |> assign(:modal, %{modal | changeset: changeset})
    |> save()
    |> res()
  end

  #@impl true
  #def handle_event("cancel", _, socket), do: cancel(socket) |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end

