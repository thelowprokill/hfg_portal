# How to add new app.

## Create new app.
- dc run -w /app/apps app mix phx.new.ecto ${APP_NAME} --database postgres

- set username, password, hostname, and database in config/dev.exs
-   username: System.get_env("POSTGRES_USERNAME", "postgres"),
-   password: System.get_env("POSTGRES_PASSWORD", "postgres"),
-   hostname: System.get_env("POSTGRES_HOST",     "localhost"),
-   database: "hfg_portal_${APP_NAME}",

- sudo chown -R $USER:$USER .

- add config :${APP_NAME}, env: :dev to the end of config/dev.exs

- add :${APP_NAME} to @apps in apps/hfg_portal/lib/hfg_portal/release.ex

- add $name to docker/development/entrypoint.sh

- dc up

## Helpers
### table
- the bnw_table component is used to create tables.
- Do not put a table inside a grid. It will not work right.
- required args:
- - inner_block
- - header
- optional args:
- - id
- - height
- simple example:
<.bnw_table id={id}>
  <:header>
    <tr>
      <th class="p-2">Name</th>
      <th class="p-2"></th>
      <th class="p-2"></th>
    </tr>
  </:header>
  <%= for item <- items do %>
    <tr>
      <td class="p-2"><%= item.name %></td>
      <td class="px-2"><.bnw_button_edit   phx-value-id={item.id} /></td>
      <td class="px-2"><.bnw_button_delete phx-value-id={item.id} /></td>
    </tr>
  <% end %>
</.bnw_table>

### Modal
- the bnw_modal component is used to create modals.
- required args:
- - inner_block
- - id
- optional args:
- - event
- - width
- - opacity
- the modal component uses three helpers: bnw_modal_header, bnw_modal_body, and bnw_modal_footer
- modals are using a modal stack to properly unwind modals.
- the stack is stored as a list of maps, the maps must have these keys:
- - modal  # key name for the modal
- - module # module name for the modal
- - live   # bool for if live view
- - id     # id for the modal
- simple example:
<.bnw_modal id={id}>
  <.bnw_modal_header>Header</.bnw_modal_header>
  <.bnw_modal_body>
    <.form :let={f} for={@changeset} phx-submit="save" phx-validate="validate" phx-target={@myself}>
      <.bnw_input f={f} field={:name} display_name="Name" />
    </.form>
  </.bnw_modal_body>
</.bnw_modal>

### buttons
- there are several canned button components. look at hfg_portal_web/live/helpers/buttons.ex for an up to date complete list.
- all buttons pass all arguments to the underlying button tag except phx-click which is taken as phx_click
- bnw_button                # base button, all buttons call this
- bnw_button_icon           # base icon button, all icon buttons call this
- bnw_button_load_more      # hidden button that is called on render to load more items, used for infinite scrolling
- bnw_button_admin_pill     # blue button with red outline
- bnw_button_admin
- bnw_button_primary_pill   # blue button
- bnw_button_primary
- bnw_button_secondary_pill # dark button
- bnw_button_secondary
- bnw_button_success_pill   # green button
- bnw_button_success
- bnw_button_danger_pill    # red button
- bnw_button_danger
- bnw_button_muted_pill     # gray button
- bnw_button_muted
- bnw_button_default_pill   # clear button with border
- bnw_button_default
- bnw_button_submit         # primary submit button takes inner block or save by default
- bnw_button_new            # primary pill add new button takes inner block or Add New by default
- bnw_button_cancel         # default cancel button takes inner block or Cancel by default
- bnw_button_done           # same as cancel but says done
- bnw_button_x              # icon button for close modal
- bnw_button_save           # primary button not tagged submit
- bnw_button_edit           # icon button edit
- bnw_button_copy           # icon button copy
- bnw_button_delete         # icon button delete
- bnw_button_up             # icon button up
- bnw_button_down           # icon button down


## Update files
- /mix.exs
- /apps/hfg_portal/lib/hfg_portal/release.ex
- /apps/hfg_portal/mix.exs
- /apps/hfg_portal_web/mix.exs
