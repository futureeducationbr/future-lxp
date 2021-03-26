# Mails sent out to teams, as a whole.
class StartupMailer < SchoolMailer
  def feedback_as_email(startup_feedback)
    @startup_feedback = startup_feedback
    send_to = startup_feedback.timeline_event.founders.map { |e| "#{e.fullname} <#{e.email}>" }
    @school = startup_feedback.startup.school

    subject = "Novo feedback de #{startup_feedback.faculty.name} sobre o seu envio."
    simple_roadie_mail(send_to, subject)
  end
end
