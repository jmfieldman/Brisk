Pod::Spec.new do |s|

    s.name         = "Brisk"
    s.version      = "2.2.1"
    s.summary      = "Concise concurrency manipulation for Swift"

    s.description  = <<-DESC
                     Concise concurrency manipulation for Swift
                     DESC

    s.homepage     = "https://github.com/jmfieldman/Brisk"
    s.license      = { :type => "MIT", :file => "LICENSE" }
    s.author       = { "Jason Fieldman" => "jason@fieldman.org" }
    s.social_media_url = 'http://fieldman.org'

    s.ios.deployment_target = "8.0"
    s.osx.deployment_target = "10.10"
    s.tvos.deployment_target = "9.0"
    s.watchos.deployment_target = "2.0"

    s.source = { :git => "https://github.com/jmfieldman/Brisk.git", :tag => "#{s.version}" }
    s.source_files = "Brisk/*.swift"

    s.requires_arc = true

end