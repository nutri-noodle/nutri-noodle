module Gender
  extend ActiveSupport::Concern
  unless self.const_defined?(:GENDERS)
    self.const_set :GENDERS, %w(male female)
  end
end
