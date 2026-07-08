defmodule HfgPortalWeb.Timekeeping.Jobs.Modals.LogTime do
  use HfgPortalWeb, :live_component

  alias Timekeeping.TimeEntries

  @key "time_entry"

  @impl true
  def update(assigns, socket) do
    %{job: job} = assigns.modal.opts

    socket
    |> assign(assigns)
    |> assign(:job, job)
    |> fetch_entries()
    |> assign_new_entry_form()
    |> res(:ok)
  end

  defp fetch_entries(socket) do
    job = socket.assigns.job

    socket
    |> assign(:open_entry, TimeEntries.get_open_for_job(job.id))
    |> assign(:history, TimeEntries.list_for_job(job.id))
    |> assign_total_seconds()
  end

  defp assign_total_seconds(socket) do
    total =
      socket.assigns.history
      |> Enum.reduce(0, fn
        %{end_time: nil}, acc -> acc
        %{start_time: start_time, end_time: end_time}, acc -> acc + DateTime.diff(end_time, start_time)
      end)

    assign(socket, :total_seconds, total)
  end

  defp assign_new_entry_form(socket) do
    if Map.has_key?(socket.assigns, :entry_changeset) do
      socket
    else
      socket |> assign(:entry_changeset, TimeEntries.new_changeset(%{job_id: socket.assigns.job.id}))
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="log_time">
        <.bnw_modal_header><%= @job.name %></.bnw_modal_header>

        <.bnw_modal_body>
          <div class="rounded-lg border border-zinc-200 dark:border-zinc-700 p-4 mb-4 flex items-center justify-between">
            <%= if @open_entry do %>
              <div>
                <span class="text-xs font-medium text-green-600 dark:text-green-400 uppercase tracking-wide">Running</span>
                <div class="text-sm text-zinc-500">
                  Since <span phx-hook="LocalTime" id="log_time_running_since" data-utc={DateTime.to_iso8601(@open_entry.start_time)}></span>
                </div>
                <div
                  class="font-mono text-lg tabular-nums text-zinc-900 dark:text-white"
                  phx-hook="ElapsedTimer"
                  id={"log_time_elapsed_#{@open_entry.id}"}
                  data-start={DateTime.to_iso8601(@open_entry.start_time)}
                >00:00:00</div>
              </div>
              <.bnw_button_danger phx_click="stop" phx-target={@myself}>
                <span class="inline-flex items-center gap-1.5">
                  <svg class="w-6 h-6" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                    <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2" />
                    <line x1="12" y1="12" x2="12" y2="7.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
                    <line
                      x1="12" y1="12" x2="15.5" y2="12"
                      stroke="currentColor" stroke-width="2" stroke-linecap="round"
                      class="origin-center animate-spin"
                      style="animation-duration: 2s"
                    />
                  </svg>
                  Stop
                </span>
              </.bnw_button_danger>
            <% else %>
              <div class="text-sm text-zinc-500">Not currently running</div>
              <.bnw_button_success phx_click="start" phx-target={@myself}>Start</.bnw_button_success>
            <% end %>
          </div>

          <div class="flex items-center justify-between px-1 pb-4 text-sm text-zinc-500">
            <span>Total time logged</span>
            <%= if @open_entry do %>
              <span
                class="font-mono text-base tabular-nums text-zinc-900 dark:text-white"
                phx-hook="ElapsedTimer"
                id={"log_time_total_#{@open_entry.id}"}
                data-start={DateTime.to_iso8601(@open_entry.start_time)}
                data-base-seconds={@total_seconds}
              ><%= format_seconds(@total_seconds) %></span>
            <% else %>
              <span class="font-mono text-base tabular-nums text-zinc-900 dark:text-white"><%= format_seconds(@total_seconds) %></span>
            <% end %>
          </div>

          <.form :let={f}
            for={@entry_changeset}
            phx-target={@myself}
            phx-change="validate"
            phx-submit="save">

            <.bnw_input_hidden f={f} field={:job_id} value={@job.id} />

            <div class="grid grid-cols-2 gap-2 px-2">
              <div>
                <label class="block text-sm font-medium leading-6 text-gray-900 dark:text-white">Start time</label>
                <input type="datetime-local" phx-hook="LocalDatetimeInput" id="log_time_start_visible" data-hidden-id="log_time_start_hidden"
                       class="mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6 dark:bg-zinc-800 dark:text-white border-zinc-300 focus:border-zinc-400" />
                <input type="hidden" id="log_time_start_hidden" name="time_entry[start_time]" value={datetime_to_iso(Phoenix.HTML.Form.input_value(f, :start_time))} />
              </div>
              <div>
                <label class="block text-sm font-medium leading-6 text-gray-900 dark:text-white">End time</label>
                <input type="datetime-local" phx-hook="LocalDatetimeInput" id="log_time_end_visible" data-hidden-id="log_time_end_hidden"
                       class="mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6 dark:bg-zinc-800 dark:text-white border-zinc-300 focus:border-zinc-400" />
                <input type="hidden" id="log_time_end_hidden" name="time_entry[end_time]" value={datetime_to_iso(Phoenix.HTML.Form.input_value(f, :end_time))} />
              </div>
            </div>

            <%= if @entry_changeset.action && not @entry_changeset.valid? do %>
              <div class="px-2 pt-1 text-sm text-red-500">
                <%= for {field, {msg, _}} <- @entry_changeset.errors do %>
                  <div><%= field %>: <%= msg %></div>
                <% end %>
              </div>
            <% end %>

            <div class="flex gap-2 px-2 pt-3">
              <.bnw_button_submit>
                <%= if @entry_changeset.data.id, do: "Update Entry", else: "Add Entry" %>
              </.bnw_button_submit>
              <%= if @entry_changeset.data.id do %>
                <.bnw_button_muted phx_click="new_entry" phx-target={@myself} type="button">Cancel Edit</.bnw_button_muted>
              <% end %>
            </div>
          </.form>

          <div class="pt-6">
            <div class="text-xs font-medium text-zinc-500 uppercase tracking-wide pb-2">History</div>
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead>
                  <tr class="border-b border-zinc-200 dark:border-zinc-700 text-left text-zinc-500">
                    <th class="pb-2 pr-4 font-medium">Start</th>
                    <th class="pb-2 pr-4 font-medium">End</th>
                    <th class="pb-2 pr-4 font-medium">Duration</th>
                    <th class="pb-2"></th>
                    <th class="pb-2"></th>
                  </tr>
                </thead>
                <tbody>
                  <%= for entry <- @history do %>
                    <tr class="border-b border-zinc-100 dark:border-zinc-800">
                      <td class="py-2 pr-4"><span phx-hook="LocalTime" id={"log_time_entry_start_#{entry.id}"} data-utc={DateTime.to_iso8601(entry.start_time)}></span></td>
                      <td class="py-2 pr-4">
                        <%= if entry.end_time do %>
                          <span phx-hook="LocalTime" id={"log_time_entry_end_#{entry.id}"} data-utc={DateTime.to_iso8601(entry.end_time)}></span>
                        <% else %>
                          <span class="text-green-600 dark:text-green-400">Running</span>
                        <% end %>
                      </td>
                      <td class="py-2 pr-4"><%= format_duration(entry.start_time, entry.end_time) %></td>
                      <td class="py-2 pr-2"><.bnw_button_edit phx_click="edit_entry" phx-value-id={entry.id} phx-target={@myself} /></td>
                      <td class="py-2"><.bnw_button_delete phx_click="delete_entry" phx-value-id={entry.id} phx-target={@myself} /></td>
                    </tr>
                  <% end %>
                  <%= if @history == [] do %>
                    <tr>
                      <td colspan="5" class="py-8 text-center text-zinc-400">No time entries yet</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </.bnw_modal_body>
        <.bnw_modal_footer><.bnw_button_cancel /></.bnw_modal_footer>
      </.bnw_modal>
    </div>
    """
  end

  defp datetime_to_iso(nil), do: ""
  defp datetime_to_iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp datetime_to_iso(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp datetime_to_iso(iso) when is_binary(iso), do: iso

  defp format_duration(_start_time, nil), do: "—"
  defp format_duration(start_time, end_time) do
    seconds = DateTime.diff(end_time, start_time)
    hours   = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    "#{hours}h #{String.pad_leading(to_string(minutes), 2, "0")}m"
  end

  defp format_seconds(seconds) do
    hours   = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs    = rem(seconds, 60)
    :io_lib.format("~2..0B:~2..0B:~2..0B", [hours, minutes, secs]) |> IO.iodata_to_binary()
  end

  @impl true
  def handle_event("start", _, socket) do
    %{job: job, modal: %{user: user}} = socket.assigns
    TimeEntries.start_now(job.id, user.id)
    socket |> fetch_entries() |> res()
  end

  @impl true
  def handle_event("stop", _, socket) do
    case socket.assigns.open_entry do
      nil   -> socket |> res()
      entry ->
        TimeEntries.stop_now(entry.id)
        socket |> fetch_entries() |> res()
    end
  end

  @impl true
  def handle_event("edit_entry", %{"id" => id}, socket) do
    changeset = id |> String.to_integer() |> TimeEntries.get() |> TimeEntries.change()
    socket |> assign(:entry_changeset, changeset) |> res()
  end

  @impl true
  def handle_event("delete_entry", %{"id" => id}, socket) do
    TimeEntries.delete(String.to_integer(id))
    socket |> fetch_entries() |> res()
  end

  @impl true
  def handle_event("new_entry", _, socket) do
    socket |> assign(:entry_changeset, TimeEntries.new_changeset(%{job_id: socket.assigns.job.id})) |> res()
  end

  @impl true
  def handle_event("validate", params, socket) do
    %{entry_changeset: changeset} = socket.assigns
    params = Map.get(params, @key, %{})
    changeset = changeset.data |> TimeEntries.change(params) |> Map.put(:action, :insert)
    socket |> assign(:entry_changeset, changeset) |> res()
  end

  @impl true
  def handle_event("save", params, socket) do
    %{entry_changeset: changeset} = socket.assigns
    params = Map.get(params, @key, %{})
    changeset = changeset.data |> TimeEntries.change(params) |> Map.put(:action, :insert)

    if changeset.valid? do
      changeset.data
      |> TimeEntries.create_or_update(changeset.changes)
      |> case do
        {:ok, _} ->
          socket
          |> assign(:entry_changeset, TimeEntries.new_changeset(%{job_id: socket.assigns.job.id}))
          |> fetch_entries()
          |> res()
        {:error, cs} ->
          socket |> assign(:entry_changeset, cs) |> res()
      end
    else
      socket |> assign(:entry_changeset, changeset) |> res()
    end
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
