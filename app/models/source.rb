class Source < ActiveRecord::Base
  attr_accessible
  has_paper_trail on: [:create, :update]
  has_many :accounts
  has_many :project_sources
  has_many :projects , through: :project_sources
  belongs_to :user

  has_annotations

  mount_uploader :avatar, ImageUploader
  validates_presence_of :name, :slogan

  def user_id_callback(value, mapping_ids)
    user = User.where(name: value).last
    user.nil? ? nil : user.id
  end

end
