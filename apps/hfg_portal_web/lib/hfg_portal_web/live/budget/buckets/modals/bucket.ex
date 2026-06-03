defmodule HfgPortalWeb.Budget.Buckets.Modals.ChangeBucket do
  use HfgPortalWeb, :live_component

  @module Budget.Buckets
  @key    "bucket"

  @impl true
  def update(assigns, socket) do
    bucket_type =
      if assigns.modal.changeset.data.monthly_contribution,
        do: "sinking_fund",
        else: "normal"

    socket
    |> assign(assigns)
    |> assign(:bucket_type, bucket_type)
    |> res(:ok)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="bucket">
        <.bnw_modal_header><.bnw_modal_new_or_edit changeset={@modal.changeset}>Bucket</.bnw_modal_new_or_edit></.bnw_modal_header>

        <.form :let={f}
          for={@modal.changeset}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save">
          <.bnw_modal_body>

            <.bnw_input_hidden f={f} field={:user_id} value={@modal.user.id} />

            <.bnw_input f={f} field={:name}        display_name="Name" />
            <.bnw_input f={f} field={:description} type="textarea" display_name="Description" />

            <div class="flex gap-6 px-2 py-3 border-t border-zinc-200 dark:border-zinc-700">
              <label class="flex items-center gap-2 cursor-pointer text-sm font-medium text-zinc-700 dark:text-zinc-300">
                <input type="radio"
                       phx-click="set_type"
                       phx-value-bucket_type="normal"
                       phx-target={@myself}
                       checked={@bucket_type == "normal"}
                       class="accent-blue-500" />
                Normal Bucket
              </label>
              <label class="flex items-center gap-2 cursor-pointer text-sm font-medium text-zinc-700 dark:text-zinc-300">
                <input type="radio"
                       phx-click="set_type"
                       phx-value-bucket_type="sinking_fund"
                       phx-target={@myself}
                       checked={@bucket_type == "sinking_fund"}
                       class="accent-blue-500" />
                Sinking Fund
              </label>
            </div>

            <%= if @bucket_type == "normal" do %>
              <.bnw_input f={f} field={:monthly_budget} type="money" display_name="Monthly Budget" />
            <% else %>
              <.bnw_input f={f} field={:monthly_contribution} type="money" display_name="Monthly Contribution" />
              <.bnw_input f={f} field={:max_balance}          type="money" display_name="Max Balance" />
            <% end %>

          </.bnw_modal_body>
          <.bnw_modal_footer><.bnw_button_cancel /><.bnw_button_submit /></.bnw_modal_footer>
        </.form>
      </.bnw_modal>
    </div>
    """
  end

  defp save(socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns

    if changeset.valid? do
      changeset.data
      |> @module.create_or_update(changeset.changes)
      |> case do
        {:ok, _}     -> cancel(socket)
        {:error, cs} -> socket |> assign(:modal, %{modal | changeset: cs})
      end
    else
      socket
    end
  end

  defp cancel(socket) do
    send(self(), :cancel)
    socket
  end

  @impl true
  def handle_event("set_type", %{"bucket_type" => type}, socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns

    cleared_changes =
      case type do
        "normal"       -> Map.merge(changeset.changes, %{monthly_contribution: nil, max_balance: nil})
        "sinking_fund" -> Map.merge(changeset.changes, %{monthly_budget: nil})
        _              -> changeset.changes
      end

    updated_changeset =
      changeset.data
      |> @module.change(cleared_changes)
      |> Map.put(:action, :insert)

    socket
    |> assign(:bucket_type, type)
    |> assign(:modal, %{modal | changeset: updated_changeset})
    |> res()
  end

  @impl true
  def handle_event("validate", params, socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns
    params = Map.get(params, @key, %{})
    changeset = changeset.data |> @module.change(params) |> Map.put(:action, :insert)
    socket |> assign(:modal, %{modal | changeset: changeset}) |> res()
  end

  @impl true
  def handle_event("save", params, socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns
    params = Map.get(params, @key, %{})
    changeset = changeset.data |> @module.change(params) |> Map.put(:action, :insert)
    socket |> assign(:modal, %{modal | changeset: changeset}) |> save() |> res()
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
