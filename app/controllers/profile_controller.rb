class ProfileController < ApplicationController

  before_action :load_profile

  def show
  end
  def create
    @profile = current_user.build_profile(profile_params)
    saved = @profile.save
    redirect_to messages_path if saved
  end

  def update
    if @profile.update(profile_params)
      @messages = current_user.messages
      respond_to do |format|
        format.turbo_stream { render 'messages/index'}
      end
    end
  end

  def destroy
    @profile.destroy
  end

  def profile_params
    hash = params.require(:profile).permit!.to_h # (:medical_condition_ids, :allergen_ids, :dietary_preference_ids, *Profile.column_names)
    hash[:medical_condition_ids]=hash[:medical_condition_ids]&.reject(&:blank?)
    hash[:allergen_ids]=hash[:allergen_ids]&.reject(&:blank?)
    hash[:dietary_preference_ids]=hash[:dietary_preference_ids]&.reject(&:blank?)
    Rails.logger.debug("hash=#{hash}")
    hash
  end
  def load_profile
    @profile = current_user.profile || current_user.build_profile
  end
end
