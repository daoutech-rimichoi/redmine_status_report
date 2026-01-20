module RedmineStatusReportHelper
  extend ActionView::Helpers::DateHelper

  # 일감의 전체 상태 변경 이력을 로드 (Raw SQL 제거 및 Ruby 로직으로 대체)
  def self.load_all(issue)
    transitions = []

    # 1. 초기 상태 구하기 (이슈 생성 ~ 첫 번째 변경 전까지)
    # Journal 중에서 status_id가 변경된 기록만 시간순으로 가져옴
    status_journals = issue.journals
                           .joins(:details)
                           .where(journal_details: { prop_key: 'status_id' })
                           .includes(:user, :details)
                           .order(:created_on)
                           .distinct

    # 상태 이름과 사용자 이름 캐싱 (N+1 방지)
    # 모든 상태 ID와 사용자 ID를 수집하여 한 번에 조회
    status_ids = [issue.status_id]
    user_ids = [issue.author_id]

    status_journals.each do |j|
      j.details.each do |d|
        if d.prop_key == 'status_id'
          status_ids << d.old_value.to_i if d.old_value
          status_ids << d.value.to_i if d.value
        end
      end
      user_ids << j.user_id
    end

    status_map = IssueStatus.where(id: status_ids.uniq).index_by(&:id)
    user_map = User.where(id: user_ids.uniq).index_by(&:id)

    # 2. 이력 구성 로직
    if status_journals.any?
      # 2-1. 첫 번째 변경 이전의 구간 (Initial State)
      first_change = status_journals.first
      first_detail = first_change.details.find { |d| d.prop_key == 'status_id' }
      
      # old_value는 문자열로 저장되므로 정수 변환 주의
      initial_status_id = first_detail.old_value.to_i
      
      transitions << {
        'status_id' => initial_status_id,
        'status_name' => status_map[initial_status_id]&.name || l(:label_unknown),
        'user_id' => issue.author_id,
        'user_name' => user_map[issue.author_id]&.name || l(:label_anonymous),
        'since' => issue.created_on,
        'till' => first_change.created_on
      }

      # 2-2. 중간 변경 이력들
      status_journals.each_with_index do |journal, idx|
        detail = journal.details.find { |d| d.prop_key == 'status_id' }
        next unless detail # 혹시 모를 방어 코드

        current_status_id = detail.value.to_i
        next_journal = status_journals[idx + 1]
        
        # 다음 변경이 있으면 그 시간까지, 없으면 현재 시간까지
        till_time = next_journal ? next_journal.created_on : Time.current

        transitions << {
          'status_id' => current_status_id,
          'status_name' => status_map[current_status_id]&.name || l(:label_unknown),
          'user_id' => journal.user_id,
          'user_name' => user_map[journal.user_id]&.name || l(:label_anonymous),
          'since' => journal.created_on,
          'till' => till_time
        }
      end
    else
      # 변경 이력이 없는 경우: 생성 시점부터 현재까지 하나의 상태
      transitions << {
        'status_id' => issue.status_id,
        'status_name' => issue.status.name,
        'user_id' => issue.author_id,
        'user_name' => user_map[issue.author_id]&.name || issue.author.name,
        'since' => issue.created_on,
        'till' => Time.current
      }
    end

    # 3. 시간 차이(초) 및 비율 계산
    total_seconds = 0
    transitions.each do |t|
      # till이 nil인 경우(아직 진행 중) 처리
      end_time = t['till'] || Time.current
      start_time = t['since']
      
      duration = (end_time - start_time).to_i
      t['transition_age_secs'] = duration
      total_seconds += duration
    end

    running_total = 0.0
    transitions.each do |t|
      if total_seconds > 0
        percent = (100.0 * t['transition_age_secs'] / total_seconds).round(2)
        t['percent'] = percent
        # running_total은 이전 항목들의 합
        t['percent_running_total'] = running_total.round(2)
        running_total += percent
      else
        t['percent'] = 0
        t['percent_running_total'] = 0
      end
    end

    # 4. 이슈가 닫힌(Closed) 경우 마지막 항목 처리 (기존 로직 유지)
    if issue.closed? && transitions.any?
      last_rec = transitions.last
      last_rec['till'] = nil
      last_rec['transition_age_secs'] = nil
      last_rec['percent'] = 0
      last_rec['percent_running_total'] = 0
    end

    transitions
  end

  # 상태별 요약 통계 로드
  def self.load_stats(issue)
    all_transitions = load_all(issue)

    # 상태별 그룹화 및 합산
    stats = all_transitions.group_by { |t| t['status_name'] }.map do |status_name, entries|
      total_secs = entries.sum { |e| e['transition_age_secs'].to_i }
      {
        'status_name' => status_name,
        'total_status_secs' => total_secs
      }
    end

    # 전체 합계 및 비율 재계산
    total_all_secs = stats.sum { |s| s['total_status_secs'] }

    stats.each do |row|
      if total_all_secs > 0
        row['percent'] = (100.0 * row['total_status_secs'] / total_all_secs).round(2)
      else
        row['percent'] = 0
      end
    end

    stats
  end

  def self.secs_to_duration_string(secs)
    if secs.nil?
      return nil
    end

    distance_of_time_in_words(0, secs, include_seconds: true)
  end

  def self.render_status_progress_bar(width, offset = 0)
    # width나 offset이 nil일 경우 방어
    width ||= 0
    offset ||= 0

    ActionController::Base.helpers.content_tag(:div, class: 'status-report-progress-container') do
      ActionController::Base.helpers.content_tag(:div, '', 
        class: 'status-report-progress-bar', 
        style: "width: #{width}%; left: #{offset}%;"
      )
    end
  end
end
