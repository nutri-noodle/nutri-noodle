class Profile < ApplicationRecord
  include ActionView::RecordIdentifier
  include Gender
  # include HeightConversion

  belongs_to :goal
  belongs_to :user, inverse_of: :profile

  ### give everyone a default goal that can be
  ### refined later.
  ### HACK HACK HACK - don't bother filter amoung all the available goals,
  ### since we have only one in the DB at the moment.
  def initialize(attributes={})
    super(attributes)
    self.goal = Goal.first
  end

  has_many :profile_medical_conditions, dependent: :destroy
  has_many :medical_conditions, through: :profile_medical_conditions
  has_many :profile_allergens, dependent: :destroy
  has_many :allergens, through: :profile_allergens
  has_many :profile_dietary_preferences, dependent: :destroy
  has_many :dietary_preferences, through: :profile_dietary_preferences
  # validates :birthdate, :gender, presence: true
  validates :gender, inclusion: { in: GENDERS }

  broadcasts_to(->(profile) { profile.user.dom_id(profile.user, :profile) },
                target: ->(profile) { profile.user.dom_id(profile.user, :profile) })

end
