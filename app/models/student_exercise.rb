class StudentExercise < ActiveRecord::Base
  belongs_to :student_assignment
  belongs_to :assignment_exercise
  
  before_destroy :destroyable?
  
  validates :student_assignment_id, :presence => true
  validates :assignment_exercise_id, :presence => true, 
                                     :uniqueness => {:scope => :student_assignment_id}
  
  attr_accessible :automated_credit, :content_cache, :free_response, :free_response_confidence, 
                  :free_response_submitted_at, :manual_credit, :selected_answer, 
                  :selected_answer_submitted_at, :was_submitted_late
                  
  def destroyable?
    raise NotYetImplemented
  end
end