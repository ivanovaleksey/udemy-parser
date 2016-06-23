#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'active_support/hash_with_indifferent_access'
require 'active_support/inflector'
require 'ruby-progressbar'
require 'open-uri'
require 'optparse'
require 'logger'
require 'json'
require 'yaml'
require 'csv'

options = {}
OptionParser.new do |opts|
  options[:level] = 'ERROR'
  opts.on("-l", "--level [LEVEL]", String, "Log level (default #{options[:level]})") do |level|
    options[:level] = level
  end

  opts.on("-h", "--help", "Displays help") do
    puts opts
    exit
  end
end.parse!

class Script

  def initialize(args)
    @args = args
    @logger = Logger.new 'dev.log'
    @logger.level = ['Logger', args[:level]].join('::').constantize
  end

  def call
    @logger.debug format('start')
    fetch_courses
    write_csv
    @logger.debug format('done')
  end

  private

  def fetch_courses
    @courses = channels.map do |channel|
      @logger.debug channel[:title]
      get_courses_by_url courses_api_url(channel[:id])
    end.flatten
  end

  def write_csv
    CSV.open(output_filename, 'w', col_sep: '^', encoding: 'UTF-8') do |file|
      file << headers
      @courses.each { |course| file << course_row(course) }
    end
  end

  def get_courses_by_url(url)
    data = JSON.parse data_by_url(url)
    @logger.debug data['next']
    current = data['results'].map { |course| course_hash course }
    next_courses = data['next'] ? get_courses_by_url(data['next']) : []
    current + next_courses
  end

  def course_hash(course)
    {
      id:                 course['id'],
      title:              course['title'],
      url:                course['url'],
      price:              course['price'],
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
      course[:id],
      course[:title],
      course[:url],
      course[:price],
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
      data = data['results'].map { |channel| ActiveSupport::HashWithIndifferentAccess.new channel }
      data.insert 1, { id: 1624, title: 'Business', url_title: '/courses/business/' }
    end
  end

  def channels_api_url
    'https://www.udemy.com/api-2.0/discovery-units/12016/channels'
  end

  def data_by_url(url)
    open(url).read
  end

  def courses_api_url(channel_id)
    format 'https://www.udemy.com/api-2.0/channels/%{channel_id}/courses?is_angular_app=true', channel_id: channel_id
  end

  def output_filename
    format 'udemy-courses-%s.csv', Date.today.strftime('%d-%m-%Y')
  end

  def headers
    @headers ||= [
      :id,
      :title,
      :url,
      :price,
      :rating,
      :subscribers,
      :reviews,
      :published_lectures,
      :level,
      :duration,
      :published_at
    ]
  end

end

Script.new(options).call
