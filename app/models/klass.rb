class Klass < ActiveRecord::Base
  belongs_to :course
  belongs_to :consent_form
  has_one :learning_plan, :as => :learning_plannable, :dependent => :destroy
  has_many :sections, :dependent => :destroy
  has_many :cohorts, :dependent => :destroy, :order => :number
  has_many :educators, :dependent => :destroy

  validates :start_date, :presence => true
  validates :end_date, :presence => true, :date => {:after => :start_date}
  validates :course_id, :presence => true
  validates :time_zone, :presence => true

  before_destroy :destroyable?
  before_create :set_first_instructor
  before_create :init_learning_plan
  before_create :init_first_section
  before_create :init_first_cohort

  attr_accessor :source_learning_plan_id, :creator

  attr_accessible :start_date, :end_date, :approved_emails, :time_zone, 
                  :source_learning_plan_id, :is_controlled_experiment,
                  :allow_student_specified_id
  
  def registration_requests
    RegistrationRequest.joins{section.klass}.where{section.klass.id == self.id}
  end
  
  def is_preapproved?(user)
    approved_emails_array = (approved_emails || '').split("\n").collect{|ae| ae.strip}

    approved_emails_array.any? do |ae|
      user.email.downcase == ae.downcase || 
      user.email.downcase.match(ae.downcase)
    end
  end

  def is_educator?(user)
    educators.any?{|e| e.user_id == user.id}
  end

  def is_instructor?(user)  # TODO change all of these to use Squeel
    educators.any?{|e| e.user_id == user.id && e.is_instructor}
  end

  def is_teaching_assistant?(user)
    educators.any?{|e| e.user_id == user.id && (e.is_instructor || e.is_teaching_assistant)}
  end

  def is_grader?(user)
    educators.any?{|e| e.user_id == user.id && (e.is_instructor || e.is_teaching_assistant || e.is_grader)}
  end
  
  def is_student?(user)
    query_student_for(user).nil?
  end
  
  def is_active_student?(user)
    query_student_for(user).active.any?
  end
  
  def student_for(user)
    query_student_for(user).first
  end
  
  # The returned student scope can include dropped students
  def query_student_for(a_user)
    Student.joins{section.klass}
           .joins{:user}
           .where{(section.klass.id == self.id)}
           .where{(user.id == a_user.id)}
  end

  #############################################################################
  # Access control methods
  #############################################################################

  def can_be_read_by?(user)
    true
  end

  def can_be_created_by?(user)
    course.is_instructor?(user) || user.is_administrator?
  end

  def can_be_updated_by?(user)
    is_educator?(user) || user.is_administrator?
  end

  def can_be_destroyed_by?(user)
    is_educator?(user) || user.is_administrator?
  end
  
  def children_can_be_read_by?(user, children_symbol)
    case children_symbol
    when :sections
      is_educator?(user) || user.is_administrator?
    end
  end

protected

  def destroyable?
    return true if sections.empty? || sudo_enabled?
    errors.add(:base, "This class cannot be deleted because it has sections.")
    false
  end

  def set_first_instructor
    return if creator.nil? || creator.is_anonymous?
    self.educators << Educator.new(:user => creator, :is_instructor => true)
  end

  def init_learning_plan
    raise NotYetImplemented if !source_learning_plan_id.nil?
    self.learning_plan = LearningPlan.new({:name => "#{course.name} (#{Time.zone.now.strftime('%b %Y')})"})
  end

  def init_first_section
    self.sections << Section.new(:name => "Main")
  end
  
  def init_first_cohort
    self.cohorts << Cohort.new
  end

end