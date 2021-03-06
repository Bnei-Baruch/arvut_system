class User < ActiveRecord::Base
  # The user may be author of question/questionnaire
  has_many :questions, :foreign_key => :author_id, :dependent => :nullify
  has_many :questionnaires, :foreign_key => :author_id, :dependent => :nullify # created by myself
  # This is not answer, this is link to an *original* questionnaire that the user answered to!!!
  has_many :answered_questionnaires, :source => :questionnaire, :through => :questionnaire_answers, :uniq => true
  has_many :questionnaire_answers, :foreign_key => :author_id, :dependent => :destroy # which I answered

  has_many :user_activities, :dependent => :destroy
  has_many :activities, :through => :user_activities
  has_and_belongs_to_many :roles
  belongs_to :language
  belongs_to :user_list

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :lockable and :timeoutable
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :trackable,
    :validatable, :confirmable, :lockable

  scope :wanted_noitification, Proc.new { |locale|
    lang = Language.get_id_by_locale(locale)
    where(:notifybyemail => 'yes', :language_id => lang)
  }

  before_create :update_user_list
  after_destroy :roles_cleanup
  
  state_machine :state, :initial => :idle do

    
    event :sign_in do # add event to devise #Done
      transition any => :signed_in
    end

    event :came_home do # add event to home_controller #Done
      transition :signed_in => :profile_edit, :if => :update_profile?
      transition :signed_in => :answer_new_questionnaire, :if => :has_new_questionnaire?
      transition any => :dashboard
    end

    event :came_to_answer_questionnaire do # add event to questionnaire_answers_controller #Done
      transition :signed_in => :specific_q_and_profile_edit, :if => :update_profile?
      transition :signed_in => :specific_q
      transition :dashboard => :specific_q
    end

    event :finished_answering_questionnaire do # add event to questionnaire_answers_controller #Done
      transition any => :dashboard
    end

    event :sign_out do # add event to devise #Done
      transition any => :signed_out
    end

    event :specific_questionnaire_is_already_answered_or_not_found do # add event to questionnaire_answers_controller #Done
      transition any => :dashboard
    end

    event :finished_editing_profile do # add event to profiles_controller #Done
      transition :specific_q_and_profile_edit => :specific_q
      transition :profile_edit => :answer_new_questionnaire, :if => :has_new_questionnaire?
      transition any => :dashboard
    end

    state :specific_q do
      def redirect
        "redirect_to new_questionnaire_answer_url"
      end
    end

    state :dashboard do
      def redirect
        "redirect_to dashboard_url"
      end
    end

    state :signed_out do
      def redirect
        "redirect_to dashboard_url"
      end
    end

    state :profile_edit do
      def redirect
        "redirect_to edit_profile_url(#{self.id})"
      end
    end

    state :specific_q_and_profile_edit do
      def redirect
        "redirect_to edit_profile_url(#{self.id})"
      end
    end

    state :answer_new_questionnaire do
      def redirect
        questionnaire = last_unanswered_questionnaire
        questionnaire ?
          "redirect_to new_questionnaire_answer_url(:questionnaire_id => #{questionnaire.id})" :
          "redirect_to dashboard_url"
      end
    end

  end

  def has_new_questionnaire?
    last_unanswered_questionnaire
  end
  
  #  Returns last unanswered questionnaire or nil if none exists
  def last_unanswered_questionnaire
    last_unanswered = unanswered_questionnaires.last rescue nil
    the_very_last = Questionnaire.by_language_published(I18n.default_locale).last
    last_unanswered == the_very_last ? last_unanswered : nil
  end

  #  returns array of unanswered questionnaires in the same language of the user
  def unanswered_questionnaires
    (Questionnaire.by_language_published(I18n.default_locale).all - answered_questionnaires) rescue []
  end


  PROFILE_FIELDS = [
    {
      :id => 'first_name',
      :label => 'user.model.first_name',
      :required => true,
      :type => 'text'
    },
    {
      :id => 'last_name',
      :label => 'user.model.last_name',
      :required => true,
      :type => 'text'
    },
    {
      :id => 'gender',
      :label => 'user.model.gender',
      :required => true,
      :type => 'radio',
      :options => {'user.model.male' => 'male', 'user.model.female' => 'female'}
    },
    {
      :id => 'birthday',
      :label => 'user.model.birthday',
      :required => true,
      :type => 'range',
      :range => [''] + (1900..Time.now.year).to_a.reverse,
      #:default => 1980
    },
    # The following two options were removed by request of Dion
    #{
    #:id => 'notifybyemail',
    #:label => 'user.model.receive_notifications',
    #:required => true,
    #:type => 'radio',
    #:options => {'user.model.yes_answer' => 'yes', 'user.model.no_answer' => 'no'}
    #},
    #{
    #:id => 'language_id',
    #:label => 'user.model.preferred_language',
    #:required => true,
    #:type => 'select',
    #:options => Language.options_for_select
    #}
  ]

  # checks whether the profile should be updated
  def update_profile?
    not is_profile_ok?
  end

  #  Checks whether all required fields in profile are filled in
  def is_profile_ok?
    PROFILE_FIELDS.each{|field|
      value = self[field[:id]]
      return false if (value.nil? || value.empty?) && field[:required]
    }
    true
  end

  #  Allowed activities: ['login', 'logout', 'submit profile', 'submit questionnaire_answer']
  def register_activity(name)
    activities << Activity.get_activity(name) rescue "Activity - '#{name}' is not allowed!"
  end

  Role.all.each{|rr|
    define_method("is_#{rr.role.downcase}?") {
      roles.map{|r| r.role}.include?("#{rr.role}")
    }
  }
  
  def last_10_questionnaires
    last_10 = Questionnaire.last_10_published(I18n.default_locale)
    last_10.all.map{|q|
      {
        :id => q.id,
        :date => q.created_at,
        :title => q.title,
        :answered => q.answered_questionnaire?(self)
      }
    }
  end

  # Make login email case insensitive
  def self.find_for_authentication(conditions)
    conditions[:email].strip!
    conditions[:email].downcase!
    super(conditions)
  end

  # One time function to normalize emails to downcase
  def self.convert_email_to_downcase
    User.all.each do |e|
      begin
        e.email.strip!
        e.email.downcase!
        e.save!
      rescue Exception => ex
        puts e.email, ex
      end

    end
  end

  private

  def update_user_list
    self.email = self.email.strip.downcase
    u_l = UserList.where(:email => self.email).first
    self.user_list = u_l
  end

  def roles_cleanup
    roles.clear unless roles.empty?
  end

end
