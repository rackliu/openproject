# OpenProject Avatars plugin
#
# Copyright (C) 2017  OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'gravatar_image_tag'
require 'avatar_helper'

AvatarHelper.class_eval do
  include ::GravatarImageTag
  include ::AngularHelper

  GravatarImageTag.configure do |c|
    c.include_size_attributes = false
  end

  # Override gems's method in order to avoid deprecated URI.escape
  GravatarImageTag.define_singleton_method(:url_params) do |gravatar_params|
    return nil if gravatar_params.keys.size == 0

    array = gravatar_params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }
    "?#{array.join('&')}"
  end

  module InstanceMethods
    # Returns the avatar image tag for the given +user+ if avatars are enabled
    # +user+ can be a User or a string that will be scanned for an email address (eg. 'joe <joe@foo.bar>')
    def avatar(principal, options = {})
      build_principal_avatar_tag principal, options
    rescue StandardError => e
      Rails.logger.error "Failed to create avatar for #{principal}: #{e}"
      ''.html_safe
    end

    def avatar_url(user, options = {})
      if local_avatar? user
        user_avatar_url(user.id)
      elsif avatar_manager.gravatar_enabled?
        build_gravatar_image_url user, options
      else
        super
      end
    rescue StandardError => e
      Rails.logger.error "Failed to create avatar url for #{user}: #{e}"
      ''.html_safe
    end

    def local_avatar?(user)
      return false unless avatar_manager.local_avatars_enabled?

      user.respond_to?(:local_avatar_attachment) && user.local_avatar_attachment
    end

    def avatar_manager
      ::OpenProject::Avatars::AvatarManager
    end

    def build_gravatar_image_url(user, options = {})
      mail = extract_email_address(user)
      raise ArgumentError.new('Invalid Mail') unless mail.present?

      opts = options.merge(gravatar: default_gravatar_options)
      # gravatar_image_url expects gravatar options as second arg
      if opts[:gravatar]
        opts.merge!(opts.delete(:gravatar))
      end

      gravatar_image_url(mail, opts)
    end

    def build_principal_avatar_tag(user, options = {})
      tag_options = merge_default_avatar_options(user, options)

      principal_type = API::V3::Principals::PrincipalType.for(user)
      principal = {
        href: API::V3::Utilities::PathHelper::ApiV3Path.send(principal_type, user.id),
        name: user.name,
        id: user.id
      }

      angular_component_tag 'op-principal',
                            class: tag_options[:class],
                            inputs: {
                              principal: principal,
                              size: tag_options[:size],
                              hideName: tag_options[:hide_name]
                            }
    end

    def merge_default_avatar_options(user, options)
      default_options = {
        size: 'default',
        hide_name: true
      }

      default_options[:title] = h(user.name) if user.respond_to?(:name)

      options.reverse_merge(default_options)
    end

    def default_gravatar_options
      {
        secure: OpenProject::Configuration.secure_connection?,
        default: OpenProject::Configuration.gravatar_fallback_image
      }
    end

    ##
    # Get a mail address used for Gravatar
    def extract_email_address(object)
      if object.respond_to?(:mail)
        object.mail
      end
    end
  end

  prepend InstanceMethods
end
