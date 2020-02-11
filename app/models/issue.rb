class Issue < ApplicationRecord

  def self.download(repo_full_name)
    remote_issues = github_client.issues(repo_full_name, state: 'all')
    remote_issues.each do |remote_issue|
      begin
        issue = Issue.find_or_create_by(repo_full_name: repo_full_name, number: remote_issue.number)
        issue.title = remote_issue.title.delete("\u0000")
        issue.body = remote_issue.body.try(:delete, "\u0000")
        issue.state = remote_issue.state
        issue.html_url = remote_issue.html_url
        issue.comments_count = remote_issue.comments
        issue.user = remote_issue.user.login
        issue.closed_at = remote_issue.closed_at
        issue.created_at = remote_issue.created_at
        issue.updated_at = remote_issue.updated_at
        issue.org = repo_full_name.split('/').first
        issue.save if issue.changed?
      rescue ArgumentError
        # derp
      end
    end
  end

  def self.github_client
    client = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'], auto_paginate: true)
  end

  def self.org_repo_names(org_name)
    github_client.org_repos(org_name).map(&:full_name)
  end

  def self.download_org_repos(org_name)
    org_repo_names(org_name).each{|repo_full_name| download(repo_full_name) }
  end

  def self.active_repo_names
    Issue.where('created_at > ?', 6.months.ago).pluck(:repo_full_name).uniq
  end

  def self.download_active_repos
    active_repo_names.each{|repo_full_name| download(repo_full_name) }
  end

  def pull_request?
    html_url && html_url.match?(/\/pull\//i)
  end
end
