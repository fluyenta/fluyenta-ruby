# frozen_string_literal: true

module BrainzLab
  module Rails
    module ViewHelpers
      # Renders the appropriate logo based on environment:
      #   1. BRAINZLAB_SITE        → BrainzLab SVG icon + text
      #   2. BRAINZLAB_LOGO_*_URL  → Custom logo images (white-label)
      #   3. Default               → Fluyenta logo images
      def brainzlab_logo_tag(height: "h-12")
        if ENV["BRAINZLAB_SITE"]
          brainzlab_svg_logo
        else
          brainzlab_img_logo(height)
        end
      end

      private

      def brainzlab_svg_logo
        icon = tag.div(class: "w-9 h-9 rounded-xl flex items-center justify-center shadow-sm", style: "background: #a3e635;") do
          tag.svg(class: "w-6 h-6", viewBox: "0 0 24 24", fill: "none", xmlns: "http://www.w3.org/2000/svg") do
            tag.path(d: "M9 3h6v1H9V3z", fill: "#2d2d2d") +
            tag.path(d: "M10 4h4v6l4.5 7.5a1.5 1.5 0 01-1.3 2.25H6.8a1.5 1.5 0 01-1.3-2.25L10 10V4z", fill: "white", stroke: "#2d2d2d", "stroke-width": "1.8", "stroke-linejoin": "round") +
            tag.path(d: "M10 10h4", stroke: "#2d2d2d", "stroke-width": "1.2", "stroke-linecap": "round")
          end
        end

        label = tag.span("Brainz Lab", class: "text-[15px] font-semibold dm-text tracking-tight")

        tag.div(class: "flex items-center gap-2.5") { icon + label }
      end

      def brainzlab_img_logo(height)
        light_url = BrainzLab.configuration.logo_light_url
        dark_url  = BrainzLab.configuration.logo_dark_url

        tag.img(src: light_url, alt: "Fluyenta", class: "#{height} dark:hidden") +
          tag.img(src: dark_url, alt: "Fluyenta", class: "#{height} hidden dark:block")
      end
    end
  end
end
