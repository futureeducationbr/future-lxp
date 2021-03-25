require 'rails_helper'

feature 'Target Overlay', js: true do
  include UserSpecHelper
  include MarkdownEditorHelper
  include NotificationHelper
  include DevelopersNotificationsHelper

  let(:course) { create :course }
  let(:grade_labels_for_1) { [{ 'grade' => 1, 'label' => 'Bad' }, { 'grade' => 2, 'label' => 'Good' }, { 'grade' => 3, 'label' => 'Great' }, { 'grade' => 4, 'label' => 'Wow' }] }
  let!(:criterion_1) { create :evaluation_criterion, course: course, max_grade: 4, pass_grade: 2, grade_labels: grade_labels_for_1 }
  let!(:criterion_2) { create :evaluation_criterion, course: course }
  let!(:level_0) { create :level, :zero, course: course }
  let!(:level_1) { create :level, :one, course: course }
  let!(:level_2) { create :level, :two, course: course }
  let!(:team) { create :startup, level: level_1 }
  let!(:student) { team.founders.first }
  let!(:target_group_l0) { create :target_group, level: level_0 }
  let!(:target_group_l1) { create :target_group, level: level_1, milestone: true }
  let!(:target_group_l2) { create :target_group, level: level_2 }
  let!(:target_l0) { create :target, :with_content, target_group: target_group_l0 }
  let!(:target_l1) { create :target, :with_content, :with_default_checklist, target_group: target_group_l1, role: Target::ROLE_TEAM, evaluation_criteria: [criterion_1, criterion_2], completion_instructions: Faker::Lorem.sentence, sort_index: 0 }
  let!(:target_l2) { create :target, :with_content, target_group: target_group_l2 }
  let!(:prerequisite_target) { create :target, :with_content, target_group: target_group_l1, role: Target::ROLE_TEAM, sort_index: 2 }
  let!(:target_draft) { create :target, :draft, :with_content, target_group: target_group_l1, role: Target::ROLE_TEAM }
  let!(:target_archived) { create :target, :archived, :with_content, target_group: target_group_l1, role: Target::ROLE_TEAM }

  # Quiz target
  let!(:quiz_target) { create :target, :with_content, target_group: target_group_l1, days_to_complete: 60, role: Target::ROLE_TEAM, resubmittable: false, completion_instructions: Faker::Lorem.sentence, sort_index: 3 }
  let!(:quiz) { create :quiz, target: quiz_target }
  let!(:quiz_question_1) { create :quiz_question, quiz: quiz }
  let!(:q1_answer_1) { create :answer_option, quiz_question: quiz_question_1 }
  let!(:q1_answer_2) { create :answer_option, quiz_question: quiz_question_1 }
  let!(:quiz_question_2) { create :quiz_question, quiz: quiz }
  let!(:q2_answer_1) { create :answer_option, quiz_question: quiz_question_2 }
  let!(:q2_answer_2) { create :answer_option, quiz_question: quiz_question_2 }
  let!(:q2_answer_3) { create :answer_option, quiz_question: quiz_question_2 }
  let!(:q2_answer_4) { create :answer_option, quiz_question: quiz_question_2 }

  before do
    # Set correct answers for all quiz questions.
    quiz_question_1.update!(correct_answer: q1_answer_2)
    quiz_question_2.update!(correct_answer: q2_answer_4)

    # Set a custom size for the embedded image.
    image_block = target_l1.current_content_blocks.find_by(block_type: ContentBlock::BLOCK_TYPE_IMAGE)
    image_block['content']['width'] = 'sm'
    image_block.save!
  end

  around do |example|
    Time.use_zone(student.user.time_zone) { example.run }
  end

  scenario 'student selects a target to view its content' do
    sign_in_user student.user, referrer: curriculum_course_path(course)

    # The target should be listed as part of the curriculum.
    expect(page).to have_content(target_group_l1.name)
    expect(page).to have_content(target_group_l1.description)
    expect(page).to have_content(target_l1.title)

    # Click on the target.
    click_link target_l1.title

    # The overlay should now be visible.
    expect(page).to have_selector('.course-overlay__body-tab-item')

    # And the page path must have changed.
    expect(page).to have_current_path("/targets/#{target_l1.id}")

    ## Ensure different components of the overlay display the appropriate details.

    # Header should have the title and the status of the current status of the target.
    within('.course-overlay__header-title-card') do
      expect(page).to have_content(target_l1.title)
    end

    # Learning content should include an embed, a markdown block, an image, and a file to download.
    expect(page).to have_selector('.learn-content-block__embed')
    expect(page).to have_selector('.markdown-block')
    content_blocks = target_l1.current_content_blocks
    image_caption = content_blocks.find_by(block_type: ContentBlock::BLOCK_TYPE_IMAGE).content['caption']
    expect(page).to have_content(image_caption)
    expect(page).to have_selector('.max-w-sm.mx-auto')
    file_title = content_blocks.find_by(block_type: ContentBlock::BLOCK_TYPE_FILE).content['title']
    expect(page).to have_link(file_title)
  end

  scenario 'aluno envia trabalho em um módulo' do
    sign_in_user student.user, referrer: target_path(target_l1)

    # This target should have a 'Complete' section.
    find('.course-overlay__body-tab-item', text: 'Concluido').click
    # completion instructions should be show on complete section for evaluated targets
    expect(page).to have_text(target_l1.completion_instructions)
    long_answer = Faker::Lorem.sentence

    replace_markdown long_answer

    click_button 'Enviar'

    expect(page).to have_content('Seu envio foi colocado na fila para revisão')

    dismiss_notification

    # The state of the target should change.
    within('.course-overlay__header-title-card') do
      expect(page).to have_content('Revisão pendente')
    end

    # The submissions should mention that review is pending.
    expect(page).to have_content('Revisão pendente')

    # The student should be able to undo the submission at this point.
    expect(page).to have_button('Desfazer envio')

    # User should be looking at their submission now.
    expect(page).to have_content('Suas submissões')

    # Let's check the database to make sure the submission was created correctly
    last_submission = TimelineEvent.last
    expect(last_submission.checklist).to eq([{ 'kind' => Target::CHECKLIST_KIND_LONG_TEXT, 'title' => 'Write something about your submission', 'result' => long_answer, 'status' => TimelineEvent::CHECKLIST_STATUS_NO_ANSWER }])

    # The status should also be updated on the dashboard page.
    click_button 'Fechar'

    within("a[aria-label='Select Target #{target_l1.id}'") do
      expect(page).to have_content('Revisão pendente')
    end

    # Return to the submissions & feedback tab on the target overlay.
    click_link target_l1.title
    find('.course-overlay__body-tab-item', text: 'Envios e Feedback').click

    # The submission contents should be on the page.
    expect(page).to have_content(long_answer)

    # User should be able to undo the submission.
    accept_confirm do
      click_button('Desfazer envio')
    end

    # This action should reload the page and return the user to the content of the target.
    expect(page).to have_selector('.learn-content-block__embed')

    # The last submissions should have been deleted...
    expect { last_submission.reload }.to raise_exception(ActiveRecord::RecordNotFound)

    # ...and the complete section should be accessible again.
    expect(page).to have_selector('.course-overlay__body-tab-item', text: 'Concluido')
  end

  scenario "student visits the target's link with a mangled ID" do
    sign_in_user student.user, referrer: target_path(id: "#{target_l1.id}*")

    expect(page).to have_selector('h1', text: target_l1.title)
  end

  context 'when the target is auto-verified' do
    let!(:target_l1) { create :target, :with_content, target_group: target_group_l1, role: Target::ROLE_TEAM, completion_instructions: Faker::Lorem.sentence }

    scenario 'student completes an auto-verified target' do
      notification_service = prepare_developers_notification

      sign_in_user student.user, referrer: target_path(target_l1)

      # There should be a mark as complete button on the learn page.
      expect(page).to have_button('Marcar como Concluido')

      # Completion instructions should be show on learn section for auto-verified targets
      expect(page).to have_text('Antes de marcar como completo')
      expect(page).to have_text(target_l1.completion_instructions)

      # The complete button should not be highlighted.
      expect(page).not_to have_selector('.complete-button-selected')

      # Clicking the mark as complete tab option should highlight the button.
      find('.course-overlay__body-tab-item', text: 'Marcar como Concluido').click
      expect(page).to have_selector('.complete-button-selected')

      click_button 'Marcar como Concluido'

      # The button should be replaced with a 'completed' marker.
      expect(page).to have_selector('.complete-button-selected', text: 'Concluido')

      # The target should be marked as passed.
      expect(page).to have_selector('.course-overlay__header-title-card', text: 'Concluido')

      # Since this is a team target, other students shouldn't be listed as pending.
      expect(page).not_to have_content('Você tem membros da equipe que ainda não completaram esta meta')

      # Target should have been marked as passed in the database.
      expect(target_l1.status(student)).to eq(Targets::StatusService::STATUS_PASSED)

      submission = TimelineEvent.last
      expect_published(notification_service, course, :submission_automatically_verified, student.user, submission)
    end

    context 'when the target requires student to visit a link to complete it' do
      let(:link_to_complete) { "https://www.example.com/#{Faker::Lorem.word}" }
      let!(:target_with_link) { create :target, :with_content, target_group: target_group_l1, link_to_complete: link_to_complete, completion_instructions: Faker::Lorem.sentence }

      scenario 'o aluno completa uma meta visitando um link' do
        sign_in_user student.user, referrer: target_path(target_with_link)

        # There should be a un-highligted button on the learn page that lets student complete the target.
        expect(page).to have_button('Visite o link para completar')
        expect(page).not_to have_selector('.complete-button-selected')

        # Completion instructions should be show on learn section for targets with link to complete
        expect(page).to have_text('Before visiting the link')
        expect(page).to have_text(target_with_link.completion_instructions)

        # Clicking the tab should highlight the button.
        find('.course-overlay__body-tab-item', text: 'Visite o link para completar').click
        expect(page).to have_selector('.complete-button-selected')

        # Clicking the button should complete the target and send the student to the link.
        new_window = window_opened_by { click_button 'Visite o link para completar' }

        # User should be redirected to the link_to_visit.
        within_window new_window do
          expect(page).to have_current_path(link_to_complete, url: true)
          page.driver.browser.close
        end

        # Target should now be complete for the user.
        expect(page).to have_selector('.course-overlay__header-title-card', text: 'Concluido')

        # Target should have been marked as passed in the database.
        expect(target_with_link.status(student)).to eq(Targets::StatusService::STATUS_PASSED)
      end
    end

    scenario 'o aluno completa uma meta respondendo a um teste' do
      notification_service = prepare_developers_notification

      sign_in_user student.user, referrer: target_path(quiz_target)

      within('.course-overlay__header-title-card') do
        expect(page).to have_content(quiz_target.title)
      end

      find('.course-overlay__body-tab-item', text: 'Faça o teste').click

      # Completion instructions should be show on Take Quiz section for targets with quiz
      expect(page).to have_text('Instruções')
      expect(page).to have_text(quiz_target.completion_instructions)

      # Question one
      expect(page).to have_content(/Question #1/i)
      expect(page).to have_content(quiz_question_1.question)
      find('.quiz-root__answer', text: q1_answer_1.value).click
      click_button('Próxima Pergunta')

      # Question two
      expect(page).to have_content(/Question #2/i)
      expect(page).to have_content(quiz_question_2.question)
      find('.quiz-root__answer', text: q2_answer_4.value).click
      click_button('Enviar Teste')

      expect(page).to have_content('Suas respostas foram salvas')
      expect(page).to have_selector('.course-overlay__body-tab-item', text: 'Resultado')

      within('.course-overlay__header-title-card') do
        expect(page).to have_content(quiz_target.title)
        expect(page).to have_content('Concluído')
      end

      # The quiz result should be visible.
      within("div[aria-label='Question 1") do
        expect(page).to have_content('Incorreta')
      end

      expect(page).to have_content("Sua resposta: #{q1_answer_1.value}")
      expect(page).to have_content("Resposta correta: #{q1_answer_2.value}")

      find("div[aria-label='Question 2']").click

      within("div[aria-label='Question 2") do
        expect(page).to have_content('Correta')
      end

      expect(page).to have_content("Sua resposta correta: #{q2_answer_4.value}")

      submission = TimelineEvent.last
      # The score should have stored on the submission.
      expect(submission.quiz_score).to eq('1/2')

      expect_published(notification_service, course, :submission_automatically_verified, student.user, submission)
    end
  end

  context 'when previous submissions exist, and has feedback' do
    let(:coach_1) { create :faculty, school: course.school }
    let(:coach_2) { create :faculty, school: course.school } # The 'unknown', un-enrolled coach.
    let(:coach_3) { create :faculty, school: course.school }
    let!(:submission_1) { create :timeline_event, target: target_l1, founders: team.founders, evaluator: coach_1, created_at: 5.days.ago, evaluated_at: 1.day.ago }
    let!(:submission_2) { create :timeline_event, :with_owners, latest: true, target: target_l1, owners: team.founders, evaluator: coach_3, passed_at: 2.days.ago, created_at: 3.days.ago, evaluated_at: 1.day.ago }
    let!(:attached_file) { create :timeline_event_file, timeline_event: submission_2 }
    let!(:feedback_1) { create :startup_feedback, timeline_event: submission_1, startup: team, faculty: coach_1 }
    let!(:feedback_2) { create :startup_feedback, timeline_event: submission_1, startup: team, faculty: coach_2 }
    let!(:feedback_3) { create :startup_feedback, timeline_event: submission_2, startup: team, faculty: coach_3 }

    before do
      # Enroll one of the coaches to course, and another to the team. One should be left un-enrolled to test how that's handled.
      create(:faculty_course_enrollment, faculty: coach_1, course: course)
      create(:faculty_startup_enrollment, faculty: coach_3, startup: team)

      # First submission should have failed on one criterion.
      create(:timeline_event_grade, timeline_event: submission_1, evaluation_criterion: criterion_1, grade: 2)
      create(:timeline_event_grade, timeline_event: submission_1, evaluation_criterion: criterion_2, grade: 1) # Failed criterion

      # Second submissions should have passed on both criteria.
      create(:timeline_event_grade, timeline_event: submission_2, evaluation_criterion: criterion_1, grade: 4)
      create(:timeline_event_grade, timeline_event: submission_2, evaluation_criterion: criterion_2, grade: 2)
    end

    scenario 'student sees feedback for a reviewed submission' do
      sign_in_user student.user, referrer: target_path(target_l1)

      find('.course-overlay__body-tab-item', text: 'Envios e Feedback').click

      # Both submissions should be visible, along with grading and all feedback from coaches.
      within("div[aria-label='Details about your submission on #{submission_1.created_at.strftime('%B %-d, %Y')}']") do
        find("div[aria-label='#{submission_1.checklist.first['title']}']").click
        expect(page).to have_content(submission_1.checklist.first['result'])

        expect(page).to have_content("#{criterion_1.name}: Good")
        expect(page).to have_content("#{criterion_2.name}: Bad")

        expect(page).to have_content(coach_1.name)
        expect(page).to have_content(coach_1.title)
        expect(page).to have_content(feedback_1.feedback)

        expect(page).not_to have_content(coach_2.name)
        expect(page).not_to have_content(coach_2.title)
        expect(page).to have_content('Unknown Coach')
        expect(page).to have_content(feedback_2.feedback)
      end

      within("div[aria-label='Detalhes sobre o seu envio em #{submission_2.created_at.strftime('%B %-d, %Y')}']") do
        find("div[aria-label='#{submission_2.checklist.first['title']}']").click
        expect(page).to have_content(submission_2.checklist.first['result'])

        submission_grades = submission_2.timeline_event_grades
        expect(page).to have_content("#{criterion_1.name}: Wow")
        expect(page).to have_text("#{submission_grades.where(evaluation_criterion: criterion_1).first.grade}/#{criterion_1.max_grade}")
        expect(page).to have_content("#{criterion_2.name}: Good")
        expect(page).to have_text("#{submission_grades.where(evaluation_criterion: criterion_2).first.grade}/#{criterion_2.max_grade}")

        expect(page).to have_content(coach_3.name)
        expect(page).to have_content(coach_3.title)
        expect(page).to have_content(feedback_3.feedback)
      end

      # Adding another submissions should be possible.
      find('button', text: 'Adicionar outro envio').click

      expect(page).to have_content('Escreva algo sobre o seu envio')

      # There should be a cancel button to go back to viewing submissions.
      click_button 'Cancel'
      expect(page).to have_content(submission_1.checklist.first['title'])
    end

    context 'when the target is non-resubmittable' do
      before do
        target_l1.update(resubmittable: false)
      end

      scenario 'student cannot resubmit non-resubmittable passed target' do
        sign_in_user student.user, referrer: target_path(target_l1)

        find('.course-overlay__body-tab-item', text: 'Envios e Feedback').click

        expect(page).not_to have_selector('button', text: 'Adicionar outro envio')
      end

      scenario 'student can resubmit non-resubmittable target if its failed' do
        # Make the first failed submission the latest, and the only one.
        submission_2.destroy!

        submission_1.timeline_event_owners.update_all(latest: true) # rubocop:disable Rails/SkipsModelValidations

        sign_in_user student.user, referrer: target_path(target_l1)

        find('.course-overlay__body-tab-item', text: 'Envios e Feedback').click

        expect(page).to have_selector('button', text: 'Adicionar outro envio')
      end
    end
  end

  context "when some team members haven't completed an individual target" do
    let!(:target_l1) { create :target, :with_content, target_group: target_group_l1, role: Target::ROLE_STUDENT }
    let!(:timeline_event) { create :timeline_event, :with_owners, latest: true, target: target_l1, owners: [student], passed_at: 2.days.ago }

    scenario 'student is shown pending team members on individual targets' do
      sign_in_user student.user, referrer: target_path(target_l1)

      other_students = team.founders.where.not(id: student)

      # A safety check, in case factory is altered.
      expect(other_students.count).to be > 0

      expect(page).to have_content('You have team members who are yet to complete this target:')

      # The other students should also be listed.
      other_students.each do |other_student|
        expect(page).to have_selector("div[title='#{other_student.name} has not completed this target.']")
      end
    end
  end

  context 'when a pending target has prerequisites' do
    before do
      target_l1.prerequisite_targets << prerequisite_target
    end

    scenario 'student navigates to a prerequisite target' do
      sign_in_user student.user, referrer: target_path(target_l1)

      within('.course-overlay__header-title-card') do
        expect(page).to have_content('Bloqueado')
      end

      expect(page).to have_content('This target has pre-requisites that are incomplete.')

      # It should be possible to navigate to the prerequisite target.
      within('.course-overlay__prerequisite-targets') do
        find('span', text: prerequisite_target.title).click
      end

      within('.course-overlay__header-title-card') do
        expect(page).to have_content(prerequisite_target.title)
      end

      expect(page).to have_current_path("/targets/#{prerequisite_target.id}")
    end
  end

  context 'when the course has ended' do
    before do
      course.update!(ends_at: 1.day.ago)
    end

    scenario 'student visits a pending target' do
      sign_in_user student.user, referrer: target_path(target_l1)

      within('.course-overlay__header-title-card') do
        expect(page).to have_content(target_l1.title)
        expect(page).to have_content('Bloqueado')
      end

      expect(page).to have_content('The course has ended and submissions are disabled for all targets!')
      expect(page).not_to have_selector('.course-overlay__body-tab-item', text: 'Complete')
    end

    scenario 'student views a submitted target' do
      create :timeline_event, :with_owners, latest: true, target: target_l1, owners: team.founders

      sign_in_user student.user, referrer: target_path(target_l1)

      # The status should read locked.
      within('.course-overlay__header-title-card') do
        expect(page).to have_content(target_l1.title)
        expect(page).to have_content('Bloqueado')
      end

      # The submissions & feedback sections should be visible.
      find('.course-overlay__body-tab-item', text: 'Envios e Feedback').click

      # The submissions should mention that review is pending.
      expect(page).to have_content('Revisão Pendente')

      # The student should NOT be able to undo the submission at this point.
      expect(page).not_to have_button('Desfazer envio')
    end
  end

  context "when student's access to course has ended" do
    before do
      team.update!(access_ends_at: 1.day.ago)
    end

    scenario 'student visits a target in a course where their access has ended' do
      sign_in_user student.user, referrer: target_path(target_l1)

      within('.course-overlay__header-title-card') do
        expect(page).to have_content(target_l1.title)
        expect(page).to have_content('Bloqueado')
      end

      expect(page).to have_content('Your access to this course has ended.')
      expect(page).not_to have_selector('.course-overlay__body-tab-item', text: 'Complete')
    end
  end

  context 'when the course has a community which accepts linked targets' do
    let!(:community_1) { create :community, :target_linkable, school: course.school, courses: [course] }
    let!(:community_2) { create :community, :target_linkable, school: course.school, courses: [course] }
    let!(:topic_1) { create :topic, :with_first_post, community: community_1, creator: student.user }
    let!(:topic_2) { create :topic, :with_first_post, community: community_1, creator: student.user }
    let(:topic_title) { Faker::Lorem.sentence }
    let(:topic_body) { Faker::Lorem.paragraph }
    let!(:topic_target_l2_1) { create :topic, :with_first_post, community: community_1, target: target_l1 }
    let!(:topic_target_l2_2) { create :topic, :with_first_post, community: community_1, target: target_l1, archived: true }

    scenario 'student uses the discuss feature' do
      sign_in_user student.user, referrer: target_path(target_l1)

      # Overlay should have a discuss tab that lists linked communities.
      find('.course-overlay__body-tab-item', text: 'Discuss&atilde;o').click
      expect(page).to have_text(community_1.name)
      expect(page).to have_text(community_2.name)
      expect(page).to have_link('Ir para a comunidade', count: 2)
      expect(page).to have_link('Criar um t&oacute;pico', count: 2)
      expect(page).to have_text("There's been no recent discussion about this target.", count: 1)

      # Check the presence of existing topics
      expect(page).to have_text(topic_target_l2_1.title)
      expect(page).to_not have_text(topic_target_l2_2.title)

      # Student can ask a question related to the target in community from target overlay.
      find("a[title='Crie um tópico na comunidade #{community_1.name}'").click

      expect(page).to have_text(target_l1.title)
      expect(page).to have_text('Criar um novo tópico de discuss&atilde;o')

      # Try clearing the linking.
      click_link 'Limpar'

      expect(page).not_to have_text(target_l1.title)
      expect(page).to have_text('Criar um novo t&oacute;pico de discuss&atilde;o')

      # Let's go back to linked state and try creating a linked question.
      visit(new_topic_community_path(community_1, target_id: target_l1.id))

      fill_in 'Title', with: topic_title
      replace_markdown(topic_body)
      click_button 'Criar Tópico'

      expect(page).to have_text(topic_title)
      expect(page).to have_text(topic_body)
      expect(page).not_to have_text('Criar um novo t&oacute;pico de discussão')

      # The question should have been linked to the target.
      expect(Topic.where(title: topic_title).first.target).to eq(target_l1)

      # Return to the target overlay. Student should be able to their question there now.
      visit target_path(target_l1)
      find('.course-overlay__body-tab-item', text: 'Discussão').click

      expect(page).to have_text(community_1.name)
      expect(page).to have_text(topic_title)

      # Student can filter all questions linked to the target.
      find("a[title='Browse all topics about this target in the #{community_1.name} community'").click
      expect(page).to have_text('Limpar Filtro')
      expect(page).to have_text(topic_title)
      expect(page).not_to have_text(topic_1.title)
      expect(page).not_to have_text(topic_2.title)

      # Student see all questions in the community by clearing the filter.
      click_link 'Limpar Filtro'
      expect(page).to have_text(topic_title)
      expect(page).to have_text(topic_1.title)
      expect(page).to have_text(topic_2.title)
    end
  end

  scenario "student visits a target's page directly" do
    # The level selected in the curriculum list underneath should always match the target.
    sign_in_user student.user, referrer: target_path(target_l0)

    click_button('Fechar')

    expect(page).to have_text(target_group_l0.name)

    visit target_path(target_l2)

    click_button('Fechar')

    expect(page).to have_text(target_group_l2.name)
  end

  context 'when the user is a school admin' do
    let(:school_admin) { create :school_admin }

    context 'when the target has a checklist' do
      let(:checklist) { [{ title: 'Describe your submission', kind: Target::CHECKLIST_KIND_LONG_TEXT, optional: false }, { title: 'Attach link', kind: Target::CHECKLIST_KIND_LINK, optional: true }, { title: 'Attach files', kind: Target::CHECKLIST_KIND_FILES, optional: true }] }
      let!(:target_l1) { create :target, :with_content, checklist: checklist, target_group: target_group_l1, role: Target::ROLE_TEAM, evaluation_criteria: [criterion_1, criterion_2], completion_instructions: Faker::Lorem.sentence, sort_index: 0 }

      scenario 'admin views the target in preview mode' do
        sign_in_user school_admin.user, referrer: target_path(target_l1)

        expect(page).to have_content('You are currently looking at a preview of this course.')
        expect(page).to have_link('Alterar conteúdo', href: content_school_course_target_path(course_id: target_l1.course.id, id: target_l1.id))

        # This target should have a 'Complete' section.
        find('.course-overlay__body-tab-item', text: 'Concluído').click

        # The submit button should be disabled.
        expect(page).to have_button('Enviar', disabled: true)

        replace_markdown Faker::Lorem.sentence

        expect(page).to have_button('Enviar', disabled: true)

        fill_in 'Attach link', with: 'https://example.com?q=1'

        # The submit button should be disabled.
        expect(page).to have_button('Enviar', disabled: true)

        attach_file 'attachment_file', File.absolute_path(Rails.root.join('spec/support/uploads/faculty/human.png')), visible: false

        dismiss_notification

        # The submit button should be disabled.
        expect(page).to have_button('Enviar', disabled: true)
      end
    end

    context 'when the target is auto-verified' do
      let!(:target_l1) { create :target, :with_content, target_group: target_group_l1, role: Target::ROLE_TEAM, completion_instructions: Faker::Lorem.sentence }

      scenario 'tries to completes an auto-verified target' do
        sign_in_user school_admin.user, referrer: target_path(target_l1)

        # There should be a mark as complete button on the learn page.
        expect(page).to have_button('Marcar como Concluído', disabled: true)
      end
    end

    context 'when the target requires user to visit a link to complete it' do
      let(:link_to_complete) { "https://www.example.com/#{Faker::Lorem.word}" }
      let!(:target_with_link) { create :target, :with_content, target_group: target_group_l1, link_to_complete: link_to_complete, completion_instructions: Faker::Lorem.sentence }

      scenario 'link to complete is shown to the user' do
        sign_in_user school_admin.user, referrer: target_path(target_with_link)

        expect(page).to have_link('Visitar link', href: link_to_complete)
      end
    end

    context 'when the target requires user to take a quiz to complete it ' do
      scenario 'user can view all the questions' do
        sign_in_user school_admin.user, referrer: target_path(quiz_target)

        within('.course-overlay__header-title-card') do
          expect(page).to have_content(quiz_target.title)
        end

        find('.course-overlay__body-tab-item', text: 'Faça o teste').click

        # Question one
        expect(page).to have_content(/Question #1/i)
        expect(page).to have_content(quiz_question_1.question)
        find('.quiz-root__answer', text: q1_answer_1.value).click
        click_button('Próxima pergunta')

        # Question two
        expect(page).to have_content(/Question #2/i)
        expect(page).to have_content(quiz_question_2.question)
        find('.quiz-root__answer', text: q2_answer_4.value).click
        expect(page).to have_button('Responder', disabled: true)
      end
    end
  end

  scenario 'student navigates between targets using quick navigation bar' do
    sign_in_user student.user, referrer: target_path(target_l1)

    expect(page).to have_text(target_l1.title)

    expect(page).not_to have_link('Módulo Anterior')
    click_link 'Próximo Módulo'

    expect(page).to have_text(prerequisite_target.title)

    click_link 'Próximo Módulo'

    expect(page).to have_text(quiz_target.title)
    expect(page).not_to have_link('Próximo Módulo')

    click_link 'Módulo anterior'

    expect(page).to have_text(prerequisite_target.title)

    click_link 'Módulo anterior'

    expect(page).to have_text(target_l1.title)
  end

  scenario 'student visits a draft target page directly' do
    sign_in_user student.user, referrer: target_path(target_draft)

    expect(page).to have_text("The page you were looking for doesn't exist")
  end

  scenario 'student visits a archived target page directly' do
    sign_in_user student.user, referrer: target_path(target_archived)

    expect(page).to have_text("The page you were looking for doesn't exist")
  end

  context 'when there are two teams with cross-linked submissions' do
    let!(:team_1) { create :startup, level: level_1 }
    let!(:team_2) { create :startup, level: level_1 }

    let(:student_a) { team_1.founders.first }
    let(:student_b) { team_1.founders.last }
    let(:student_c) { team_2.founders.first }
    let(:student_d) { team_2.founders.last }

    # Create old submissions, linked to students who are no longer teamed up.
    let!(:submission_old_1) { create :timeline_event, :with_owners, target: target_l1, owners: [student_a, student_c] }
    let!(:submission_old_2) { create :timeline_event, :with_owners, target: target_l1, owners: [student_b, student_d] }

    # Create a new submission, linked to students who are currently teamed up.
    let!(:submission_new) { create :timeline_event, :with_owners, latest: true, target: target_l1, owners: team_1.founders }

    before do
      # Mark ownership of old submissions as latest for C & D, since they don't have a later submission.
      submission_old_1.timeline_event_owners.where(founder: student_c).update(latest: true)
      submission_old_2.timeline_event_owners.where(founder: student_d).update(latest: true)
    end

    scenario 'latest flag is updated correctly on deleting the latest submission for all concerned students' do
      # Delete Submission A
      sign_in_user student_a.user, referrer: target_path(target_l1)
      find('.course-overlay__body-tab-item', text: 'Envios e feedback').click

      accept_confirm do
        click_button('Desfazer envio')
      end

      # This action should delete `submission_new`, reload the page and return the user to the content of the target.
      expect(page).to have_selector('.learn-content-block__embed')

      expect { submission_new.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(target_l1.latest_submission(student_a)).to eq(submission_old_1)
      expect(target_l1.latest_submission(student_b)).to eq(submission_old_2)
      expect(target_l1.latest_submission(student_c)).to eq(submission_old_1)
      expect(target_l1.latest_submission(student_d)).to eq(submission_old_2)
    end
  end

  context 'when the team changes for a group of students' do
    let!(:team_1) { create :startup, level: level_1 }
    let!(:team_2) { create :startup, level: level_1 }

    let(:student_1) { team_1.founders.first }
    let(:student_2) { team_2.founders.first }
    let(:student_3) { team_2.founders.last }

    # Create old submissions, linked to students who are no longer teamed up.
    let!(:submission_old_1) { create :timeline_event, :with_owners, latest: true, target: target_l1, owners: team_1.founders }
    let!(:submission_old_2) { create :timeline_event, :with_owners, latest: true, target: target_l1, owners: team_2.founders }

    before do
      student_2.update!(startup: team_1)
    end

    scenario 'latest flag is updated correctly for all students' do
      sign_in_user student_1.user, referrer: target_path(target_l1)
      find('.course-overlay__body-tab-item', text: 'Concluído').click
      replace_markdown Faker::Lorem.sentence
      click_button 'Enviar'
      expect(page).to have_content('Seu envio foi colocado na fila para revisão')
      dismiss_notification

      new_submission = TimelineEvent.last
      expect(target_l1.latest_submission(student_1)).to eq(new_submission)
      expect(target_l1.latest_submission(student_2)).to eq(new_submission)
      # Latest submission is not updated for the team 2 user
      expect(target_l1.latest_submission(student_3)).to eq(submission_old_2)
    end
  end
end
