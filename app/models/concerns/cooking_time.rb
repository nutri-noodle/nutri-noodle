# converts a height (as total inches) to feet and inches
module CookingTime
  extend ActiveSupport::Concern

  included do
    attr_accessor :total_time_hours, :total_time_minutes
    attr_accessor :active_time_hours, :active_time_minutes

    validates :total_time_hours, numericality: true, allow_blank: true
    validates :total_time_minutes, numericality: true, allow_blank: true
    validates :active_time_hours, numericality: true, allow_blank: true
    validates :active_time_minutes, numericality: true, allow_blank: true

    [:total_time, :active_time].each do |method|
      validates "#{method}_hours", numericality: true, allow_blank: true
      validates "#{method}_minutes", numericality: true, allow_blank: true
      define_method("#{method}_display") do
        if !send("#{method}_hours").to_i.zero? && !send("#{method}_minutes").zero?
          "#{send("#{method}_hours")} hours #{send("#{method}_minutes")} minutes"
        elsif !(send("#{method}_hours")||0).to_i.zero?
          "#{send("#{method}_hours")} hours"
        elsif !(send("#{method}_minutes")||0).to_i.zero?
          "#{send("#{method}_minutes")} minutes"
        else
          ""
        end
      end
    end

    before_validation do
      self.total_time=total_time_hours.to_i * 60 + total_time_minutes.to_i
      self.active_time=active_time_hours.to_i * 60 + active_time_minutes.to_i
    end

    after_initialize do
      initialize_duration(:total_time)
      initialize_duration(:active_time)
    end
    def initialize_duration(field_name)
      if respond_to?(field_name) && send(field_name)
        self.send("#{field_name}_hours=", send(field_name) / 60 )
        self.send("#{field_name}_minutes=", send(field_name) % 60 )
      end
    end
  end
end

