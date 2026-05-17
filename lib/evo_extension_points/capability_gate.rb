# frozen_string_literal: true

module EvoExtensionPoints
  # Capability gate extension point. Community default: every capability is
  # enabled (single-installation mode). An external consumer can replace this
  # implementation via
  #   EvoExtensionPoints.replace(:capability_gate) { |name, **ctx| ... }
  # without patching community source. See EXTENSION_POINTS.md at the repo root.
  module CapabilityGate
    DEFAULT_IMPL = ->(_name, **_context) { true }

    class << self
      def enabled?(name, **context)
        impl = EvoExtensionPoints.impl_for(:capability_gate) || DEFAULT_IMPL
        impl.call(name, **context)
      end
    end
  end
end
