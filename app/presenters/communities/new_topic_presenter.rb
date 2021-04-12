module Communities
  class NewTopicPresenter < ApplicationPresenter
    def initialize(view_context, community, target)
      super(view_context)
      @community = community
      @target = target
    end

    def props
      p = { community_id: @community.id, topic_categories: topic_categories }
      p[:target] = @target.attributes.slice('id', 'title') if @target.present?
      p
    end

    def page_title
      "Novo Tópico | #{@community.name} Comunidade"
    end

    def topic_categories
      @community.topic_categories.map { |category| { id: category.id, name: category.name } }
    end
  end
end
