# frozen_string_literal: true

# A component for displaying alert messages
class AlertComponent < ViewComponent::Base
  def call
    safe_join(notices.map do |notice|
      next if notice.last.blank?

      content_tag :div, class: "alert alert-#{notice.first}", role: 'alert' do
        sanitize notice.last
      end
    end)
  end

  def render?
    notices.present?
  end

  private

  def notices
    Settings.notices
  end
end
