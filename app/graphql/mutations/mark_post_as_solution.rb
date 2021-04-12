module Mutations
  class MarkPostAsSolution < GraphQL::Schema::Mutation
    argument :id, ID, required: true

    description "Mark a community post as a solution"

    field :success, Boolean, null: false

    def resolve(params)
      mutator = MarkPostAsSolutionMutator.new(context, params)

      success = if mutator.valid?
        mutator.mark_post_as_solution
        mutator.notify(:success, "Feito!", "Resposta marcada como solucionada com sucesso")
        true
      else
        mutator.notify_errors
        false
      end

      { success: success }
    end
  end
end
