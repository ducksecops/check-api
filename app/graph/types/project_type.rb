ProjectType = GraphQL::ObjectType.define do
  name 'Project'
  description 'Project type'

  interfaces [NodeIdentification.interface]

  field :id, field: GraphQL::Relay::GlobalIdField.new('Project')
  field :avatar, types.String
  field :description, types.String
  field :title, !types.String
  field :dbid, types.Int
  field :permissions, types.String

  field :team do
    type TeamType

    resolve -> (project, _args, _ctx) {
      project.team
    }
  end

  connection :medias, -> { MediaType.connection_type } do
    resolve ->(project, _args, _ctx) {
      project.medias
    }
  end

  connection :sources, -> { SourceType.connection_type } do
    resolve ->(project, _args, _ctx) {
      project.sources
    }
  end

  connection :annotations, -> { AnnotationType.connection_type } do
    resolve ->(project, _args, _ctx) {
      project.annotations
    }
  end
end
