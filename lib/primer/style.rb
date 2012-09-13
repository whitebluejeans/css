require 'primer'
require 'sass'

module Primer
  module Style
    extend self

    class Logger < Sass::Logger::Base
      def _log(level, message)
        raise message
      end
    end

    # Captures anything logged by Sass
    #
    # &block - Block to capture
    #
    # Returns String log output.
    def capture_sass_logs
      old_logger = Sass.logger
      Sass.logger = Logger.new(:warn)
      yield
    ensure
      Sass.logger = old_logger
    end

    # Parse all SCSS files in a directory.
    #
    # root - String root of directory
    #
    # Returns an Array of Sass::Nodes.
    def parse_files(root)
      nodes = []
      load_paths = Primer.paths.map { |p| Sass::Importers::Filesystem.new(p) }
      Dir["#{root}/**/*.scss"].each do |path|
        data = File.read(path)
        nodes << Sass::SCSS::Parser.new(data, path).parse
        # sass wtf
        nodes.each { |node| node.options = {:filename => path, :load_paths => load_paths } }
      end
      nodes
    end

    # Iterate over all nodes in Sass tree.
    #
    # nodes - Array of Sass::Nodes returned from parse_files
    #
    # Returns nothing.
    def iterate_nodes(nodes, &block)
      nodes.each do |node|
        node.each(&block)
      end
      nil
    end

    # Run style assertions on Sass nodes.
    #
    # nodes - Array of Sass::Nodes
    #
    # Examples
    #
    #     include Primer::Style
    #     def test_style
    #       assert_style(nodes)
    #     end
    #
    # Returns nothing.
    def assert_style(nodes)
      capture_sass_logs do
        nodes.each do |node|
          assert_render_root(node)
        end
        iterate_nodes(nodes) do |node|
          assert_no_js_rules(node)
        end
      end
    end

    def assert_render_root(node)
      assert_kind_of Sass::Tree::RootNode, node
      assert node.render
    end

    # Check if any CSS rules use js- classes or ids.
    def assert_no_js_rules(node)
      return unless node.is_a?(Sass::Tree::RuleNode)
      assert_no_match(/(\#|\.)js-/,
        node.rule.first, "#{node.filename}:#{node.line} - CSS selectors can't start with js-. See http://is.gd/eFcrSg")
    end
  end
end
