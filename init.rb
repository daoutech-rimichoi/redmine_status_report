Redmine::Plugin.register :redmine_status_report do
  name 'Redmine Status Report plugin'
  author 'rimichoi'
  description 'Shows status statistics for an issue'
  version '1.0.0, Daoutech 0.0.2'
  requires_redmine :version_or_higher => '5.0.0'
  url 'https://github.com/daoutech-rimichoi/redmine_status_report'
  author_url 'mailto:rimichoi@daou.co.kr'
end
