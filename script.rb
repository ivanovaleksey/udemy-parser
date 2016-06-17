#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'active_support/hash_with_indifferent_access'
require 'ruby-progressbar'
require 'open-uri'
require 'json'
require 'csv'

class Script
  def call
    fetch_courses
    write_csv
  end

  private

  def fetch_courses
    @courses = channels.first(1).map do |channel|
    # channels.map do |channel|
      get_courses_by_url courses_api_url(channel[:id])
    end.flatten
  end

  def write_csv
    CSV.open('udemy-courses.csv', 'w', col_sep: '|', encoding: 'UTF-8') do |file|
      @courses.each { |course| file << course_row(course) }
    end
  end

  def get_courses_by_url(url)
    data = JSON.parse data_by_url(url)
    # p data
    current = data['results'].map { |course| course_hash course }
    p data['next']
    next_courses = data['next'] ? get_courses_by_url(data['next']) : []
    current + next_courses
  end

  def course_hash(course)
    {
      title:              course['title'],
      url:                course['url'],
      rating:             course['avg_rating'],
      subscribers:        course['num_subscribers'],
      reviews:            course['num_reviews'],
      published_lectures: course['num_published_lectures'],
      level:              course['instructional_level'],
      duration:           course['content_info'],
      published_at:       course['published_time']
    }
  end

  def course_row(course)
    [
      course[:title],
      course[:url],
      course[:rating],
      course[:subscribers],
      course[:reviews],
      course[:published_lectures],
      course[:level],
      course[:duration],
      course[:published_at]
    ]
  end

  def channels
    @channels ||= begin
      data = JSON.parse open(channels_api_url).read
      # data = JSON.parse File.open('channels.json').read
      data = data['results'].map { |channel| ActiveSupport::HashWithIndifferentAccess.new channel }
      data.insert 1, { id: 1624, title: 'Business', url_title: '/courses/business/' }
    end
  end

  def channels_api_url
    'https://www.udemy.com/api-2.0/discovery-units/12016/channels'
  end

  def data_by_url(url)
    open(url).read
    # File.open(url).read
  end

  def courses_api_url(channel_id)
    # case channel_id
    # when 1640 then 'development_1.json'
    # when 1624 then 'business_1.json'
    # end
    format 'https://www.udemy.com/api-2.0/channels/%{channel_id}/courses?is_angular_app=true', channel_id: channel_id
  end
end

Script.new.call
