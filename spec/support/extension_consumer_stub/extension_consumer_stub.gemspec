Gem::Specification.new do |spec|
  spec.name    = 'extension_consumer_stub'
  spec.version = '0.0.0'
  spec.authors = ['Evolution API LTDA']
  spec.email   = ['dev@evofoundation.com.br']
  spec.summary = 'CI-only fixture that exercises the EvoExtensionPoints contract'
  spec.description = <<~DESC
    Internal fixture used by the community-with-extension-consumer-stub CI
    workflow. Registers itself against every EvoExtensionPoints extension
    point with trivial counter/spy implementations so the suite fails
    immediately if a documented extension point is renamed or removed.
    Never published.
  DESC
  spec.license       = 'Nonstandard'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['allowed_push_host'] = 'none'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files         = ['lib/extension_consumer_stub.rb']
  spec.require_paths = ['lib']
end
