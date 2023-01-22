# frozen_string_literal: true

require "active_support/testing/strict_warnings"
require "active_support"
require "active_support/testing/autorun"
require "rails/configuration"
require "active_support/test_case"
require "minitest/mock"

module Rails
  module Configuration
    class MiddlewareStackProxyTest < ActiveSupport::TestCase
      class FooMiddleware; end
      class BarMiddleware; end
      class BazMiddleware; end
      class HiyaMiddleware; end

      def setup
        @stack = MiddlewareStackProxy.new
      end

      def test_playback_insert_before
        @stack.insert_before :foo
        assert_playback :insert_before, :foo
      end

      def test_playback_insert
        @stack.insert :foo
        assert_playback :insert_before, :foo
      end

      def test_playback_insert_after
        @stack.insert_after :foo
        assert_playback :insert_after, :foo
      end

      def test_playback_swap
        @stack.swap :foo
        assert_playback :swap, :foo
      end

      def test_playback_use
        @stack.use :foo
        assert_playback :use, :foo
      end

      def test_playback_delete
        @stack.delete :foo
        assert_playback :delete, :foo
      end

      def test_playback_move_before
        @stack.move_before :foo
        assert_playback :move_before, :foo
      end

      def test_playback_move
        @stack.move :foo
        assert_playback :move_before, :foo
      end

      def test_playback_move_after
        @stack.move_after :foo
        assert_playback :move_after, :foo
      end

      def test_order
        @stack.swap :foo
        @stack.delete :foo

        mock = Minitest::Mock.new
        mock.expect :swap, nil, [:foo]
        mock.expect :delete, nil, [:foo]
        mock.expect :middlewares, []
        mock.expect :middlewares=, nil, [[]]

        @stack.merge_into mock
        mock.verify
      end

      def test_create_nested_stack_proxy
        root_proxy = MiddlewareStackProxy.new
        nested_proxy = root_proxy.create_stack

        assert_not_equal root_proxy, nested_proxy
        assert nested_proxy.is_a?(MiddlewareStackProxy)
      end

      def test_nested_stack_proxies
        root_proxy = MiddlewareStackProxy.new
        root_proxy.use FooMiddleware
        root_proxy.use BarMiddleware
        outer_nested_proxy = root_proxy.create_stack
        inner_nested_proxy = root_proxy.create_stack
        outer_nested_proxy.use BazMiddleware
        outer_nested_proxy.use inner_nested_proxy
        inner_nested_proxy.use HiyaMiddleware
        root_proxy.insert_before BarMiddleware, outer_nested_proxy

        inner_nested_stack = Minitest::Mock.new
        inner_nested_stack.expect :use, nil, [HiyaMiddleware]
        inner_nested_stack.expect :middlewares, [HiyaMiddleware]
        inner_nested_stack.expect :middlewares=, nil, [[HiyaMiddleware]]
        inner_nested_stack.expect :middlewares, [HiyaMiddleware]

        outer_nested_stack = Minitest::Mock.new
        outer_nested_stack.expect :use, nil, [BazMiddleware]
        outer_nested_stack.expect :use, nil, [inner_nested_proxy]
        outer_nested_stack.expect :nested_stack, inner_nested_stack
        outer_nested_stack.expect :middlewares, [BazMiddleware, inner_nested_proxy]
        outer_nested_stack.expect :middlewares=, nil, [[BazMiddleware, HiyaMiddleware]]
        outer_nested_stack.expect :middlewares, [BazMiddleware, HiyaMiddleware]

        root_stack = Minitest::Mock.new
        root_stack.expect :use, nil, [FooMiddleware]
        root_stack.expect :use, nil, [BarMiddleware]
        root_stack.expect :insert_before, nil, [BarMiddleware, outer_nested_proxy]
        root_stack.expect :nested_stack, outer_nested_stack
        root_stack.expect :middlewares, [FooMiddleware, outer_nested_proxy, BarMiddleware]
        root_stack.expect :middlewares=, nil, [[FooMiddleware, BazMiddleware, HiyaMiddleware, BarMiddleware]]
        root_stack.expect :middlewares, [FooMiddleware, BazMiddleware, HiyaMiddleware, BarMiddleware]

        merged = root_proxy.merge_into(root_stack)
      end

      private
        def assert_playback(msg_name, args)
          mock = Minitest::Mock.new
          mock.expect msg_name, nil, [args]
          mock.expect :middlewares, []
          mock.expect :middlewares=, nil, [[]]
          @stack.merge_into(mock)
          mock.verify
        end
    end
  end
end
