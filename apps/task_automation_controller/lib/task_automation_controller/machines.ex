defmodule TaskAutomationController.Machines do
  @topic "task_automation_controller:machines"
  @schema TaskAutomationController.Jobs.Machine
  @updated [:machine, :updated]
  @created [:machine, :created]
  @deleted [:machine, :deleted]

  # Include default CRUD operations from HfgPortal.Helpers.DefaultCrud
  use HfgPortal.Helpers.DefaultCrud,
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted
end
