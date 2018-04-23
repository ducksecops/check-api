module CheckElasticSearch

  def update_media_search(keys, data = {}, parent = nil)
    return if self.disable_es_callbacks || RequestStore.store[:disable_es_callbacks]
    options = {keys: keys, data: data}
    options[:parent] = parent unless parent.nil?
    ElasticSearchWorker.perform_in(1.second, YAML::dump(self), YAML::dump(options), 'update_parent')
  end

  def add_media_search_bg(options)
    p = self.project
    ms = MediaSearch.new
    ms.team_id = p.team.id
    ms.project_id = p.id
    ms.set_es_annotated(self)
    self.add_extra_elasticsearch_data(ms)
    ms.save!
  end

  def update_media_search_bg(options)
    ms = get_elasticsearch_parent(options[:parent])
    unless ms.nil?
      data = get_elasticsearch_data(options[:data])
      fields = {'last_activity_at' => Time.now.utc}
      options[:keys].each{|k| fields[k] = data[k] if ms.respond_to?("#{k}=") and !data[k].blank? }
      ms.update fields
    end
  end

  def add_update_media_search_child(child, keys, data = {}, parent = nil)
    return if self.disable_es_callbacks || RequestStore.store[:disable_es_callbacks]
    v = self.versions.last
    version = v.nil? ? 0 : v.id
    options = {keys: keys, data: data, version: version}
    options[:parent] = parent unless parent.nil?
    ElasticSearchWorker.perform_in(1.second, YAML::dump(self), YAML::dump(options), child)
  end

  def add_update_media_search_child_bg(child, options)
    # get parent
    ms = get_elasticsearch_parent(options[:parent])
    unless ms.nil?
      child = child.singularize.camelize.constantize
      model = child.search(query: { match: { _id: self.id } }).results.last
      if model.nil?
        model = child.new
        model.id = self.id
      end
      child_options = {parent: ms.id, version: options[:version], retry_on_conflict: 0}
      store_elasticsearch_data(model, options[:keys], options[:data], child_options)
      # Update last_activity_at on parent
      ms.update last_activity_at: Time.now.utc, version: options[:version], retry_on_conflict: 1
    end
  end

  def store_elasticsearch_data(model, keys, data, options = {})
    data = get_elasticsearch_data(data)
    keys.each do |k|
      model.send("#{k}=", data[k]) if model.respond_to?("#{k}=") and !data[k].blank?
    end
    model.save!(options)
  end

  def get_parent_id
    if self.is_annotation?
      pm = get_es_parent_id(self.annotated_id, self.annotated_type)
    else
      pm = get_es_parent_id(self.id, self.class.name)
    end
    pm
  end

  def get_es_parent_id(id, klass)
    (klass == 'ProjectSource') ? Base64.encode64("ProjectSource/#{id}") : id
  end

  def get_elasticsearch_parent(parent)
    sleep 1 if Rails.env == 'test'
    # TODO : create parent if not exists
    MediaSearch.search(query: { match: { _id: parent } }).last unless parent.nil?
  end

  def get_elasticsearch_data(data)
    (data.blank? and self.respond_to?(:data)) ? self.data : data
  end

  def destroy_elasticsearch_data(data)
    options = {}
    conditions = []
    parent_id = data[:parent]
    if data[:type] == 'child'
      options = {parent: parent_id}
      id = self.id
      conditions << { has_parent: { parent_type: "media_search", query: { term: { _id: parent_id } } } }
    else
      id = parent_id
    end
    conditions << {term: { _id: id } } 
    obj = data[:es_type].search(query: { bool: { must: conditions } }).last
    obj.delete(options) unless obj.nil?
  end
end
