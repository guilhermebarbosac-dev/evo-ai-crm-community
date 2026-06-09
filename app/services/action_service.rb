class ActionService
  include EmailHelper
  # Conversation action implementations now live in a single shared
  # module so the modal and flow-canvas automation executors cannot diverge.
  # Macros::ExecutionService < ActionService reaches the same code path here.
  include AutomationRules::ConversationActionHandlers

  def initialize(conversation)
    @conversation = conversation.reload
  end

  def remove_assigned_team(_params)
    @conversation.update!(team_id: nil)
  end
end

ActionService.include_mod_with('ActionService')
