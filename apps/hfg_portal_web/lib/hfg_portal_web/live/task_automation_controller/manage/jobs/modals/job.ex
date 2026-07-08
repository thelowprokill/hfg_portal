defmodule HfgPortalWeb.TaskAutomationController.Manage.Jobs.Modals.ChangeJob do
  use HfgPortalWeb, :live_component

  @module TaskAutomationController.Jobs
  @key "job"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="jobs_modal">
        <.bnw_modal_header><.bnw_modal_new_or_edit changeset={@modal.changeset}>Job</.bnw_modal_new_or_edit></.bnw_modal_header>
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

            <.bnw_input       f={f} field={:name}         display_name="Name"/>
            <.bnw_input       f={f} field={:address}      display_name="Address"/>
            <.bnw_input       f={f} field={:description}  display_name="Description"  type="textarea"/>
            <.bnw_input       f={f} field={:priority_id}  display_name="Priority"     type="select" list={@priorities} />
            <.bnw_input_naked f={f} field={:asynchronous} display_name="Asynchronous" type="checkbox"/>
            <.bnw_input_naked f={f} field={:active}       display_name="Active"       type="checkbox"/>


          </.bnw_modal_body>
          <.bnw_modal_footer><.bnw_button_cancel /><.bnw_button_submit/></.bnw_modal_footer>
        </.form>
      </.bnw_modal>
    </div>
    """
  end

  defp fetch_priorities(socket) do
    priorities = TaskAutomationController.Priorities.list() |> Enum.map(&([key: &1.name, value: &1.id]))
    last_priority_id = priorities |> List.last() |> Keyword.get(:value)
    
    socket
    |> assign(:priorities, priorities)
    |> maybe_set_default_priority(last_priority_id)
  end
  
  defp maybe_set_default_priority(socket, priority_id) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns
    
    if is_nil(changeset.data.id) and is_nil(changeset.data.priority_id) do
      updated_changeset = changeset.data |> @module.change(%{priority_id: priority_id})
      assign(socket, :modal, %{modal | changeset: updated_changeset})
    else
      socket
    end
  end

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> fetch_priorities()
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

    params = params |> Map.get(@key, %{})

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

