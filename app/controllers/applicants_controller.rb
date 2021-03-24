class ApplicantsController < ApplicationController
  # GET /applicants/:token/enroll
  def enroll
    @applicant = Applicant.find_by(login_token: params[:token])

    if valid_applicant?
      student = Applicants::CreateStudentService.new(@applicant).create(session[:applicant_tag] || 'Public Signup')
      sign_in student.user
      flash[:success] = "Bem Vindo(a) #{current_school.name}!"
      redirect_to after_sign_in_path_for(student.user)
    else
      flash[:error] = "Esse link único expirou ou é inválido. Se você já concluiu a inscrição, faça login."
      redirect_to new_user_session_path
    end
  end

  private

  def valid_applicant?
    public_courses = current_school.courses.where(public_signup: true)
    @applicant.present? && public_courses.exists?(id: @applicant.course_id)
  end
end
