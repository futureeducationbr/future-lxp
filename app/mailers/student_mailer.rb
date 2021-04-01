class StudentMailer < SchoolMailer
  def enrollment(student)
    @school = student.course.school
    @course = student.course
    @student = student

    simple_roadie_mail(@student.email, "Você foi incluído(a) como aluno(a) em #{@school.name}")
  end
end
