#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

ENV['NLS_LANG']='AMERICAN_AMERICA.UTF8'

require 'active_support/hash_with_indifferent_access'
require 'active_support/inflector'
require 'ruby-progressbar'
require 'awesome_print'
require 'open-uri'
require 'optparse'
require 'nokogiri'
require 'logger'
require 'sequel'
require 'dotenv'
require 'json'
require 'csv'

Dotenv.load

options = {}
OptionParser.new do |opts|
  options[:level] = 'ERROR'
  opts.on("-l", "--level [LEVEL]", String, "Log level (default #{options[:level]})") do |level|
    options[:level] = level
  end

  options[:mode] = :list
  opts.on("-m", "--mode [MODE]", String, "Script mode (available options are: list, details; default #{options[:mode]})") do |mode|
    options[:mode] = mode.to_sym
  end

  opts.on("-h", "--help", "Displays help") do
    puts opts
    exit
  end
end.parse!

LOGGER = Logger.new 'dev.log'
LOGGER.level = ['Logger', options[:level]].join('::').constantize

class Script

  module Workers

    class List
      def call
        fetch_courses
        write_csv
      end

      private

      def fetch_courses
        @courses = channels.map do |channel|
          LOGGER.debug channel[:title]
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
        LOGGER.debug data['next']
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

    class Details
      DB = Sequel.connect ENV['DATABASE_URL']

      class Course < Sequel::Model
        plugin :prepared_statements
        set_dataset Sequel.lit ENV['TABLE_NAME']
        set_primary_key :offer_rk
      end

      def call
        progressbar = ProgressBar.create total: courses.count, format: '%t: [%B] %p%% (%a)'
        courses.each do |course|
          LOGGER.debug course.url
          begin
            params = course_details course
            params.merge! full_desc_uploaded_flg: 1
            course.update params
          rescue => e
            log_error course, e
          end

          progressbar.increment
        end
      end

      private

      def courses
        @courses ||= Course.where(full_desc_uploaded_flg: 0)
      end

      def course_details(course)
        html = ::Nokogiri::HTML open(course.url)
        {
          description: course_description(course, html),
          language: course_languages(course, html)
        }
      end

      def course_description(course, html)
        desc = html.at_css('div#desc')
        desc.xpath('.//@*').remove if desc

        requirements = html.at_css('div#requirements')
        requirements.xpath('.//@*').remove if requirements

        what_you_get = html.at_css('div#what-you-get')
        what_you_get.xpath('.//@*').remove if what_you_get

        who_should_attend = html.at_css('div#who-should-attend')
        who_should_attend.xpath('.//@*').remove if who_should_attend

        [desc, requirements, what_you_get, who_should_attend].reject { |el| el.nil? }.map do |el|
          el.to_s.gsub(/[\n\t\r]/, '').gsub(/\s{2,}/, '')
        end.join ''
      rescue => e
        log_error course, e
        nil
      end

      def course_languages(course, html)
        html.at_css('li.list-item span.list-left:contains("Languages")')
            .ancestors('li')
            .at_css('span.list-right')
            .text
            .gsub /\s/, ''
      rescue => e
        log_error course, e
        nil
      end

      def log_error(course, e)
        message = format("%d: %s\n%s\n%s", course.id, course.url, e.message, e.backtrace.join("\n"))
        LOGGER.error message
      end
    end

  end

  def initialize(args)
    @args = args
    define_worker
  end

  def call
    LOGGER.debug format('start')
    @worker.call
    LOGGER.debug format('done')
  end

  private

  def define_worker
    @worker = worker_class.new
  end

  def worker_class
    @worker_class ||= ['Script', 'Workers', @args[:mode].capitalize].join('::').constantize
  end

end

Script.new(options).call
