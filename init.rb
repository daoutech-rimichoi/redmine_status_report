Redmine::Plugin.register :redmine_status_report do
  name 'Redmine Status Report plugin'
  author 'rimichoi'
  description 'Shows status statistics for an issue'
  version '1.0.0, Daoutech 0.0.1'
  requires_redmine :version_or_higher => '6.0.0'
  url 'https://github.com/daoutech-rimichoi/redmine_status_report'
  author_url 'mailto:rimichoi@daou.co.kr'
end

Rails.configuration.to_prepare do
  # Zeitwerk 오토로딩을 통해 훅 클래스를 로드하여 등록
  RedmineStatusReport::Hooks
end
