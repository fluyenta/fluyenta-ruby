# frozen_string_literal: true

module BrainzLab
  module Rails
    module ViewHelpers
      BRAINZLAB_LOGO_SVG = <<~SVG.html_safe.freeze
        <svg width="160" height="40" viewBox="0 0 160 40" fill="none" xmlns="http://www.w3.org/2000/svg">
          <rect width="36" height="36" y="2" rx="8" fill="#a3e635"/>
          <path d="M13 7h10v1H13V7z" fill="#2d2d2d"/>
          <path d="M15 8h6v9l6.75 11.25a2.25 2.25 0 01-1.95 3.375H10.2a2.25 2.25 0 01-1.95-3.375L15 17V8z" fill="white" stroke="#2d2d2d" stroke-width="1.8" stroke-linejoin="round"/>
          <path d="M15 17h6" stroke="#2d2d2d" stroke-width="1.2" stroke-linecap="round"/>
          <text x="44" y="26" font-family="Inter, system-ui, -apple-system, sans-serif" font-size="17" font-weight="600" fill="#1a1a1a" letter-spacing="-0.3">Brainz Lab</text>
        </svg>
      SVG

      # Renders the appropriate logo based on environment:
      #   1. BRAINZLAB_SITE (URL)  → Image from URL
      #   2. BRAINZLAB_SITE (true) → BrainzLab inline SVG (flask icon + text)
      #   3. BRAINZLAB_LOGO_*_URL  → Custom logo images (white-label)
      #   4. Default               → Fluyenta logo images (light/dark)
      def brainzlab_logo_tag(height: "h-12")
        site = ENV["BRAINZLAB_SITE"]

        if site.present?
          if site.start_with?("http", "/")
            tag.img(src: site, alt: "Brainz Lab", class: height)
          else
            BRAINZLAB_LOGO_SVG
          end
        else
          light_url = BrainzLab.configuration.logo_light_url
          dark_url  = BrainzLab.configuration.logo_dark_url

          tag.img(src: light_url, alt: "Fluyenta", class: "#{height} dark:hidden") +
            tag.img(src: dark_url, alt: "Fluyenta", class: "#{height} hidden dark:block")
        end
      end
    end
  end
end
