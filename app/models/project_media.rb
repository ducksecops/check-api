class ProjectMedia < ActiveRecord::Base
  attr_accessible

  belongs_to :project
  belongs_to :media
  belongs_to :user

  after_create :set_search_context, :set_initial_media_status

  notifies_slack on: :create,
                 if: proc { |pm| m = pm.media; m.current_user.present? && m.current_team.present? && m.current_team.setting(:slack_notifications_enabled).to_i === 1 },
                 message: proc { |pm| pm.slack_notification_message },
                 channel: proc { |pm| m = pm.media; m.project.setting(:slack_channel) || m.current_team.setting(:slack_channel) },
                 webhook: proc { |pm| m = pm.media; m.current_team.setting(:slack_webhook) }

  notifies_pusher on: :create,
                  event: 'media_updated',
                  targets: proc { |pm| [pm.project] },
                  data: proc { |pm| pm.media.to_json }

  def get_team
    p = self.project
    p.nil? ? [] : [p.team_id]
  end

  def media_id_callback(value, mapping_ids = nil)
    mapping_ids[value]
  end

  def project_id_callback(value, mapping_ids = nil)
    mapping_ids[value]
  end

  def set_initial_media_status
    st = Status.new
    st.annotated = self.media
    st.context = self.project
    st.annotator = self.user
    st.status = Status.default_id(self.media, self.project)
    st.created_at = self.created_at
    st.save!
  end

  def slack_notification_message
    m = self.media
    data = m.data(self.project)
    if !data['quote'].blank?
      "*#{m.user.name}* added a new claim: <#{m.origin}/project/#{m.project_id}/media/#{m.id}|*#{data['quote']}*>"
    else
      "*#{m.user.name}* added a new link: <#{m.origin}/project/#{m.project_id}/media/#{m.id}|*#{data['title']}*>"
    end
  end

  private

  def set_search_context
    em_context = self.media.annotations('embed', self.project).last unless self.project.nil?
    if em_context.nil?
      em_none = self.media.annotations('embed', 'none').last
      unless em_none.nil?
        em_none.search_context << self.project.id
        em_none.save!
      end
    end
  end

end
