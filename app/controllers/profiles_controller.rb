class ProfilesController < ApplicationController

  def new
    @profile = current_user.build_profile
  end

  def create
    @profile = current_user.create_profile(profile_params)
    redirect_to messages_path if @profile.persisted?
  end

  def edit
    @profile = current_user.profile
  end

  def update
    @profile = current_user.profile
    redirect_to messages_path if @profile.update(profile_params)
  end

  def destroy
    current_user.profile.destroy
  end

  def profile_params
    hash = params.require(:profile).permit!.to_h # (:medical_condition_ids, :allergen_ids, :dietary_preference_ids, *Profile.column_names)
    hash[:medical_condition_ids]=hash[:medical_condition_ids]&.reject(&:blank?)
    hash[:allergen_ids]=hash[:allergen_ids]&.reject(&:blank?)
    hash[:dietary_preference_ids]=hash[:dietary_preference_ids]&.reject(&:blank?)
    Rails.logger.debug("hash=#{hash}")
    hash
  end
end
