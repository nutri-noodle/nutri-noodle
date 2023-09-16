module TagAssociation
  extend ActiveSupport::Concern

  class_methods do
    def tag_association(options = {})
      cattr_accessor :tag_association_options
      belongs_to :tag, :inverse_of => options[:inverse_of], :counter_cache => options[:counter_cache], :class_name => "Tag"
      belongs_to options[:owner], **options.slice(:inverse_of, :class_name, :touch)
      delegate :allergen?, :display_name, :name, :propagate, :parent_name, :visible_for_foods?, :meal_plan_tag?, :to => :tag, :allow_nil=>true

      self.tag_association_options = options
    end
  end

  def owner
    send(self.class.tag_association_options[:owner])
  end

end
