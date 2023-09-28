# converts a height (as total inches) to feet and inches
module HeightConversion
  extend ActiveSupport::Concern

  MIN_HEIGHT_IN_INCHES = 2 * 12
  MAX_HEIGHT_IN_INCHES = 8 * 12 + 11

  included do
    attr_accessor :feet, :inches

    with_options :if=>:complete? do |participant|
      participant.validates :feet,
        :inclusion => {:in => 2..8, :allow_blank => true},
        :presence => true

      participant.validates :inches,
        :inclusion => {:in => 0..11, :allow_blank => true},
        :presence => true,
        :if => Proc.new { |participant| participant.complete? && (participant.errors.attribute_names & [:feet]).blank? }

      participant.validates :height,
        :inclusion => {:in => (MIN_HEIGHT_IN_INCHES..MAX_HEIGHT_IN_INCHES),
        :allow_blank => true },
        :presence => true,
        :if => Proc.new { |participant| participant.complete? && (participant.errors.attribute_names & [:feet, :inches]).blank? }
    end

    before_validation do
      self.feet = feet.to_i unless feet.blank?
      self.inches = inches.to_i unless inches.blank?
    end

    after_initialize do
      if height
        self.feet   = height.to_i / 12
        self.inches = height.to_i % 12
      end
    end

    before_validation do
      # if you change the limits, the iphone needs the same information
      if (feet.present? && inches.present?)
        self.height = feet.to_i * 12 + inches.to_i
      end
    end

  end

  def height
    super || ((feet.present? && inches.present?) ? feet.to_i * 12 + inches.to_i : nil)
  end

  def height=(val)
    if val
      self.feet   = val.to_i / 12
      self.inches = val.to_i % 12
    end
    super(val)
  end

  def height_as_feet
    return 0 if height.nil?
    (height / 12).to_i
  end

  def height_as_inches
    return 0 if height.nil?
    height - (height_as_feet * 12)
  end

end

