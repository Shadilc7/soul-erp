module TrainerPortal
  class ProfileController < TrainerPortal::BaseController
    def show
      @trainer = current_trainer
    end
  end
end
