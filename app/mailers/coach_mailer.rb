class CoachMailer < SchoolMailer
  def course_enrollment(coach, course)
    @school = course.school
    @course = course
    @coach = coach

    simple_roadie_mail(coach.email, "Você foi incluído como mentor em #{@course.name}")
  end
end
