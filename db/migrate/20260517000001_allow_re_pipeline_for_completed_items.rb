class AllowRePipelineForCompletedItems < ActiveRecord::Migration[7.0]
  def up
    # Remove old unique indexes that prevent re-entry after completion
    remove_index :pipeline_items, name: :index_pipeline_items_on_conversation_id_and_pipeline_id, if_exists: true
    remove_index :pipeline_items, name: :index_pipeline_items_on_contact_id_and_pipeline_id, if_exists: true

    # Add new partial unique indexes: uniqueness only for ACTIVE items (completed_at IS NULL)
    # This allows a contact/conversation to have multiple completed journeys + one active
    add_index :pipeline_items, [:conversation_id, :pipeline_id],
              unique: true,
              where: 'conversation_id IS NOT NULL AND completed_at IS NULL',
              name: :idx_pipeline_items_active_conversation_per_pipeline

    add_index :pipeline_items, [:contact_id, :pipeline_id],
              unique: true,
              where: 'conversation_id IS NULL AND completed_at IS NULL',
              name: :idx_pipeline_items_active_contact_per_pipeline
  end

  def down
    remove_index :pipeline_items, name: :idx_pipeline_items_active_conversation_per_pipeline, if_exists: true
    remove_index :pipeline_items, name: :idx_pipeline_items_active_contact_per_pipeline, if_exists: true

    add_index :pipeline_items, [:conversation_id, :pipeline_id],
              unique: true,
              where: 'conversation_id IS NOT NULL',
              name: :index_pipeline_items_on_conversation_id_and_pipeline_id

    add_index :pipeline_items, [:contact_id, :pipeline_id],
              unique: true,
              where: 'conversation_id IS NULL',
              name: :index_pipeline_items_on_contact_id_and_pipeline_id
  end
end
