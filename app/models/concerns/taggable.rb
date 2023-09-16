module Taggable
  def self.included(base)
    base.class_eval do
      cattr_accessor :taggable_options
    end
    base.taggable_options ||= {}
    base.extend(Taggable::ClassMethods)
  end

  module ClassMethods
    def add_taggables(options = {})
      self.taggable_options = options
      send :include, Taggable::Methods
    end
  end

  module Methods
    def self.included(base)
      base.extend(Methods::ClassMethods)
    end

    def tag_association
      send tag_association_name
    end

    def tag_association_name
      self.class.taggable_options[:tag_association] || "#{self.class.model_name.singular}_tags".to_sym
    end

    module ClassMethods

      # See the meta-programming block below. This meta data is used to define methods.
      TAG_METHODS =
      {
        # Include a meal that has ALL of these tags
        :by         => ["main_ingredients", "dietary_preferences", "dietary_considerations", "meal_types", "speeds"],

        # Include a meal that has ANY of these tags
        :by_any     => ["main_ingredients", "meal_types", "breakfast_categories", "lunch_categories", "speeds"],

        # Exclude any meals that have one of these tags
        :exclude_by => ["main_ingredients", "allergens"],
        # Exclude any meals that have one of these tags
        :exclude_by_any => ["main_ingredients", "allergens"],
      }

      # Generates methods for searching with tags.
      #
      # Generates:
      #  - def self.by_main_ingredients
      #  - def self.by_dietary_preferences
      #  - def self.by_dietary_considerations
      #  - def self.by_meal_types
      #  - def self.by_speeds
      #  - def self.by_any_main_ingredients
      #  - def self.by_any_meal_types
      #  - def self.by_any_speeds
      #  - def self.exclude_by_main_ingredients
      #  - def self.exclude_by_allergens
      TAG_METHODS.each do |key, values|
        method = "#{key}_tag".to_sym
        values.each do |tag_name|
          name = "#{key}_#{tag_name}".to_sym
          define_method name do |tagged_ids|
            value = Array.wrap(tagged_ids)
            if value.first.to_s.match(/\D/)
              tagged_ids = Tag.send(tag_name).where("lower(tags.name) in (:names) or lower(tags.display_name) in (:names)", names: value.map(&:downcase)).ids.map(&:to_s)
            else
              tagged_ids = (Tag.send(tag_name).pluck(:id).map(&:to_s) & Array.wrap(tagged_ids).map(&:to_s))
            end
            send(method, tagged_ids)
          end
        end
      end

      # Search for taggable objects that have _all_ the provided tag ids
      #
      # @param {Integer[]} tags - ids of tags to search for.  Matched objects must have ALL these tags
      #
      def by_tag(tags)
        custom_table_name, tag_class, f_key = collect_taggable_options
        include_matching_all_tags(tags, tag_class, custom_table_name, f_key)
      end

      # Search for taggable objects that have _any_ of the provided tag ids
      #
      # @param {Integer[]} tags - ids of tags to search for.  Matched objects must have ONE these tags
      #
      def by_any_tag(tags)
        custom_table_name, tag_class, f_key = collect_taggable_options
        include_matching_any_tag(tags, tag_class, custom_table_name, f_key)
      end

      # Search for taggable objects that have _none_ of the provided tag ids
      #
      # @param {Integer[]} tags - ids of tags to exclude.  Matched objects must have NONE these tags
      #
      def exclude_by_tag(tags)
        custom_table_name, tag_class, f_key = collect_taggable_options
        exclude_matching_any_tag(tags, tag_class, custom_table_name, f_key)
      end

      private
      def collect_taggable_options
        top_class = self.respond_to?(:base_class) ? base_class : self
        [(taggable_options[:table_name] || self.table_name), taggable_options[:tag_class], (taggable_options[:foreign_key] || "#{top_class.model_name.element}_id")]
      end

      # def by_main_ingredients
      # def by_dietary_preferences
      # def by_dietary_considerations
      # def by_meal_types
      # def by_speeds
      def include_matching_all_tags(tags, tag_class, table_name, f_key)
        tags = Array.wrap(tags).reject(&:blank?)
        if tags.empty?
          none
        else
          tag_table_name = tag_class.table_name
          sql = "exists (SELECT 1 FROM #{tag_table_name} WHERE #{tag_table_name}.tag_id = ? and #{table_name}.id = #{tag_table_name}.#{f_key})"
          query = self
          tags.each { |tag_id| query = query.where(sql, tag_id) }
          query
        end
      end

      # def by_any_main_ingredients
      # def by_any_meal_types
      # def by_any_speeds
      def include_matching_any_tag(tags, tag_class, table_name, f_key)
        tags = Array.wrap(tags).reject(&:blank?)
        if tags.empty?
          all
        else
          tag_table_name = tag_class.table_name
          sql = " exists (SELECT 1 FROM #{tag_table_name} WHERE #{tag_table_name}.tag_id in (:tag_ids) and #{table_name}.id = #{tag_table_name}.#{f_key})"
          self.where(sql, :tag_ids => tags)
        end
      end

      # def exclude_by_main_ingredients
      # def exclude_by_allergens
      def exclude_matching_any_tag(tags, tag_class, table_name, f_key)
        tags = Array.wrap(tags).reject(&:blank?)
        if tags.empty?
          all
        else
          tag_table_name = tag_class.table_name
          sql = "not exists (SELECT 1 FROM #{tag_table_name} WHERE #{tag_table_name}.tag_id in (?) and #{table_name}.id = #{tag_table_name}.#{f_key})"
          where(sql, Array.wrap(tags).reject(&:blank?))
        end
      end
    end
  end
end
