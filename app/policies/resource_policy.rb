class ResourcePolicy < ApplicationPolicy
  def show?
    scope.where(id: record.id).exists?
  end

  def download?
    show?
  end

  class Scope < Scope
    def resolve
      # Return nothing if visiting a PupilFirst page.
      return scope.none if current_school.blank?

      resources = scope.live.joins(:school).left_joins(:targets)

      public_resources = resources.where(schools: { id: current_school }).where(public: true)

      # Return only public resources in current school if no founder is signed in.
      return public_resources if current_founder.blank?

      # resources linked to targets of the course founder is enrolled in
      target_linked_resources = resources.where(targets: { id: current_founder.course.targets.select(:id) })

      # private resources not linked to target
      private_resources_without_target = resources.where(schools: { id: current_school }).where(public: false)

      # Return public resources and private course resources where founder is member.
      public_resources.or(target_linked_resources).or(private_resources_without_target)
    end
  end
end
