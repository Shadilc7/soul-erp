module TrainerPortal
  class ProfilesController < TrainerPortal::BaseController
    def show
      @trainer = current_trainer
      @training_programs = @trainer.training_programs
        .includes(:section, :participants)
        .order(created_at: :desc)
        .limit(5)

      @total_programs = @trainer.training_programs.count
      @active_programs = @trainer.training_programs.ongoing.count
      @completed_programs = @trainer.training_programs.completed.count

      @total_participants = @trainer.training_programs
        .joins(:participants)
        .select("DISTINCT participants.id")
        .count
    end
  end
end
