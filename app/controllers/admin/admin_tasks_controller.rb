class Admin::AdminTasksController < ApplicationController

  before_filter :check_if_restricted

  autocomplete :user, :email, :add_also => [:first_name, :last_name], :full => true

  def index
    
  end
  
  def remove_user
  end

  def remove_user_action
    @email = params[:email]
    unless @email.empty?
      user = User.where(:email => @email).first
      if user.nil?
        # Wrong email -- user doesn't exist
        session[:alert] = 'Wrong email'
      else
        if user.destroy
          session[:notice] = 'Done'
        else
          session[:alert] = 'Unable to remove user'
        end
      end

      render :remove_user
    end
  end
end