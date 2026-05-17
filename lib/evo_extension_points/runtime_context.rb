# frozen_string_literal: true

module EvoExtensionPoints
  # Runtime context extension point. Community default: single-scope mode —
  # current_scope_id is always nil and with_scope is a pass-through. See
  # EXTENSION_POINTS.md.
  module RuntimeContext
    DEFAULT_CURRENT_ID = -> {}
    DEFAULT_WITH_SCOPE = ->(_id, &block) { block&.call }

    class << self
      def current_scope_id
        impl = EvoExtensionPoints.impl_for(:runtime_context_current_id) || DEFAULT_CURRENT_ID
        impl.call
      end

      def with_scope(id, &)
        impl = EvoExtensionPoints.impl_for(:runtime_context_with_scope) || DEFAULT_WITH_SCOPE
        impl.call(id, &)
      end
    end
  end
end
