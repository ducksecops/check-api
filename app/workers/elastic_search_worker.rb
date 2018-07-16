class ElasticSearchWorker

  include Sidekiq::Worker
  sidekiq_options :queue => :esqueue, :retry => false

  def perform(model, options, type)
    model = YAML::load(model)
    options = set_options(model, options)
    case type
    when "update_team"
      model.update_elasticsearch_team_bg
    when "update_parent"
      model.update_media_search_bg(options)
    when "add_parent"
      model.add_media_search_bg
    when "destroy"
      model.destroy_elasticsearch_data(options)
    when "update_parent_nested"
      model.add_nested_obj_bg(options)
    else
      model.add_update_media_search_child_bg(type, options)
    end
  end

  private

  def set_options(model, options)
    options = YAML::load(options)
    options[:keys] = [] unless options.has_key?(:keys)
    options[:data] = {} unless options.has_key?(:data)
    options[:obj] = model.get_es_doc_obj unless options.has_key?(:obj)
    options[:doc_id] = model.get_es_doc_id(options[:obj]) unless options.has_key?(:doc_id)
    options
  end
end
