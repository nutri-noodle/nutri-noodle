class PopulateRawContent < ActiveRecord::Migration[7.0]
  def up
    execute %Q{update messages set raw_content=content where role = 10}
    Message.assistant.to_a.map(&:save)
  end
end
