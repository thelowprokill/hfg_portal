defmodule HfgPortalWeb.Helpers.Inputs do
  use Phoenix.LiveView
  use Phoenix.HTML

  import HfgPortalWeb.CoreComponents

  ###############################################
  # input
  # useage:
  #   <.input f={@f} field={:field_name} type={:text_input} />
  ###############################################
  
  def bnw_input_hidden(assigns) do
    assigns = assigns |> assign(:name, Map.get(assigns, :name, "#{assigns.f.name}[#{assigns.field}]"))

    ~H"""
    <.input 
      type="hidden" 
      field={@f[@field]} 
      value={@value} 
      name={@name}
      id={@name}
    />
    """
  end
  
  attr :f,              :any,     required: true
  attr :field,          :any,     required: true
  attr :type,           :string,  default: "text"
  attr :display_name,   :string,  default: ""
  attr :starting_month, :integer, default: 1
  attr :offset,         :integer, default: 1
  attr :min,            :integer
  attr :max,            :integer
  attr :step,           :any
  attr :list,           :list
  attr :name,           :any
  attr :debounce,       :string
  def bnw_input(assigns) do
    ~H"""
      <div class="p-2">
        <label class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"><%= @display_name %></label>
        <div>
          <.bnw_input_naked {assigns} />
        </div>
      </div>
    """
  end 

  attr :f,              :any,     required: true
  attr :field,          :any,     required: true
  attr :type,           :string,  default: "text"
  attr :display_name,   :string,  default: ""
  attr :starting_month, :integer, default: 1
  attr :offset,         :integer, default: 1
  attr :min,            :integer
  attr :max,            :integer
  attr :step,           :any
  attr :list,           :list
  attr :name,           :any
  attr :value,          :any,     default: nil
  attr :debounce,       :string,  default: nil
  def bnw_input_naked(assigns) when assigns.type == "checkbox" do
    assigns = assigns |> assign(:name, Map.get(assigns, :name, "#{assigns.f.name}[#{assigns.field}]"))

    ~H"""
      <label class="flex pl-5 py-1">
        <.input 
          style="color: #1e87f0;"
          field={@f[@field]} 
          type="checkbox"
          placeholder={@display_name} 
          name={@name}
          phx-debounce={@debounce}
        />
        <div class="pl-3">
          <%= @display_name %>
        </div>
      </label>
    """
  end

  # this needs some help
  def bnw_input_naked(assigns) when assigns.type == "radio" do
    ~H"""
      <label class="flex pl-5 py-1">
        <.input class="
            py-1.5 
            pl-7 
            pr-20 
            text-gray-900 
            placeholder:text-gray-400 
            focus:ring-2 
            focus:ring-inset 
            focus:ring-indigo-600 
            text-primary-main
            sm:text-sm 
            sm:leading-6" 
          style="color: #1e87f0;"
          field={@f[@field]} 
          type="radio"
          placeholder={@display_name} 
          name={@name}
          phx-debounce={@debounce}
        />
        <div class="pl-3">
          <%= @display_name %>
        </div>
      </label>
    """
  end

  def bnw_input_naked(assigns) when assigns.type == "range" do
    assigns =
      assigns
      |> assign(:min,   Map.get(assigns, :min,  0))
      |> assign(:max,   Map.get(assigns, :max,  100))
      |> assign(:step,  Map.get(assigns, :step, 1))
      |> assign(:value, Map.get(assigns, :value, nil))
      |> assign(:name, Map.get(assigns, :name, "#{assigns.f.name}[#{assigns.field}]"))

    ~H"""
    <div>
      <label><%= input_value(@f, @field) %></label>
      <%= if @value do %>
        <div>
          <%= @value %>
        </div>
      <% end %>
      <div class="flex">
        <label class="pr-2"><%= @min %></label>
        <.input 
          field={@f[@field]} 
          type={@type}
          placeholder={@display_name} 
          min={@min}
          max={@max} 
          step={@step} 
          name={@name}
          phx-debounce={@debounce}
        />
        <label class="pl-2"><%= @max %></label>
      </div>
    </div>
    """
  end

  # starting_month sets what monnth to start with. For example setting 10 will start with October
  # offset 0 is 0 is January offset 1 is 1 is January
  def bnw_input_naked(assigns) when assigns.type == "month" do
    starting_month = Map.get(assigns, :starting_month, 1)
    offset         = Map.get(assigns, :offset, 1)
    months = [
      [value: adjust_starting_month( 1, starting_month, offset), key: "January"],
      [value: adjust_starting_month( 2, starting_month, offset), key: "February"],
      [value: adjust_starting_month( 3, starting_month, offset), key: "March"],
      [value: adjust_starting_month( 4, starting_month, offset), key: "April"],
      [value: adjust_starting_month( 5, starting_month, offset), key: "May"],
      [value: adjust_starting_month( 6, starting_month, offset), key: "June"],
      [value: adjust_starting_month( 7, starting_month, offset), key: "July"],
      [value: adjust_starting_month( 8, starting_month, offset), key: "August"],
      [value: adjust_starting_month( 9, starting_month, offset), key: "September"],
      [value: adjust_starting_month(10, starting_month, offset), key: "October"],
      [value: adjust_starting_month(11, starting_month, offset), key: "November"],
      [value: adjust_starting_month(12, starting_month, offset), key: "December"]
    ]
    |> Enum.sort(&(&1[:value] < &2[:value]))

    assigns =
      assigns
      |> assign(:type,  "select")
      |> assign(:list,  months)
      |> assign(:name, Map.get(assigns, :name, "#{assigns.f.name}[#{assigns.field}]"))

    ~H"<.bnw_input_naked {assigns} />"
  end

  def bnw_input_naked(assigns) when assigns.type == "select" do
    assigns =
      assigns
      |> assign(:list, Map.get(assigns, :list, []))
      |> assign(:name, Map.get(assigns, :name, "#{assigns.f.name}[#{assigns.field}]"))
      |> assign(:value, (
        if Map.get(assigns, :value) in ["", nil] do 
          assigns.f.source
          |> Map.get(:changes, %{})
          |> Map.get(assigns.field, Map.get(assigns.f.data, assigns.field, nil))
        else 
          Map.get(assigns, :value)
        end
      ))
    ~H"""
    <%= select(
      @f, 
      @field,
      @list,
      [
        id: @name,
        name: @name,
        value: @value,
        phx_debounce: @debounce,
        class: "
          mt-2 
          block 
          w-full 
          rounded-lg 
          text-zinc-900 
          focus:ring-0 
          sm:text-sm 
          sm:leading-6 
          phx-no-feedback:border-zinc-300 
          phx-no-feedback:focus:border-zinc-400 
          dark:bg-zinc-800 
          dark:text-white 
          border-zinc-300 
          focus:border-zinc-400
        "
      ])
    %>
    """
  end

  def bnw_input_naked(assigns) when assigns.type == "money" do
    assigns =
      assigns
      |> assign(:min,  Map.get(assigns, :min,  nil))
      |> assign(:max,  Map.get(assigns, :max,  nil))
      |> assign(:step, Map.get(assigns, :step, 1))
      |> assign(:name, Map.get(assigns, :name, "#{assigns.f.name}[#{assigns.field}]"))

    #<div class="flex items-center mt-2 block w-full rounded-lg dark:text-white border-zinc-300 focus:border-zinc-400">
    ~H"""
    <div class="flex items-center">
      <span class="px-1">$</span>
      <.input
        field={@f[@field]} 
        type="number"
        id={@name}
        name={@name}
        placeholder={@display_name} 
        min={@min}
        max={@max} 
        step={@step} 
        phx-debounce={@debounce}
      />
    </div>
    """
  end

  def bnw_input_naked(assigns) when assigns.type == "percent" do
    assigns =
      assigns
      |> assign(:min,  Map.get(assigns, :min,  nil))
      |> assign(:max,  Map.get(assigns, :max,  nil))
      |> assign(:step, Map.get(assigns, :step, 1))
      |> assign(:name, Map.get(assigns, :name, "#{assigns.f.name}[#{assigns.field}]"))

    ~H"""
    <div class="flex items-center">
      <.input
        field={@f[@field]} 
        type="number"
        name={@name}
        placeholder={@display_name} 
        min={@min}
        max={@max} 
        step={@step} 
        phx-debounce={@debounce}
      />
      <span class="pxl-1">%</span>
    </div>
    """
  end

  def bnw_input_naked(assigns) do
    assigns =
      assigns
      |> assign(:type,  Map.get(assigns, :type, "text"))
      |> assign(:min,   Map.get(assigns, :min,  nil))
      |> assign(:max,   Map.get(assigns, :max,  nil))
      |> assign(:step,  Map.get(assigns, :step, 1))
      |> assign(:name,  Map.get(assigns, :name, "#{assigns.f.name}[#{assigns.field}]"))
      |> assign(:value, (if Map.get(assigns, :value) in ["", nil], do: assigns.f |> Map.get(:source, %{}) |> Map.get(:changes, %{}) |> Map.get(assigns.field, Map.get(assigns.f.data, assigns.field, nil)), else: Map.get(assigns, :value)))
    #Map.get(assigns.f.source.changes, assigns.field, Map.get(assigns.f.data, assigns.field, nil)), else: Map.get(assigns, :value)))

    ~H"""
    <.input
      field={@f[@field]} 
      type={@type}
      name={@name}
      placeholder={@display_name} 
      min={@min}
      max={@max} 
      step={@step} 
      id={@name}
      value={@value}
      phx-debounce={@debounce}
    />
    """
  end

  defp adjust_starting_month(month_number, starting_month, offset) do
    month_number - (starting_month - offset)
    |> case do
      val when val < offset -> val + 12
      val -> val
    end
  end

  # this is here just for the compiler
  def render(assigns), do: ~H"<div>render</div>"
end

