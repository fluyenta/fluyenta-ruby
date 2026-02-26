# frozen_string_literal: true

module BrainzLab
  module Rails
    module ViewHelpers
      def brainzlab_logo_tag(height: "h-12")
        light_url = BrainzLab.configuration.logo_light_url
        dark_url  = BrainzLab.configuration.logo_dark_url

        tag.img(src: light_url, alt: "Fluyenta", class: "#{height} dark:hidden") +
          tag.img(src: dark_url, alt: "Fluyenta", class: "#{height} hidden dark:block")
      end
    end
  end
end
