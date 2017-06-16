require "./lib_glfw"

# Simple OO wrapper around lib_glfw
module Andromeda
  #  extend self

  class Window
    property width
    property height
    property title
    property handle : LibGLFW::Window
    property cursor

    def initialize(@width = 1920, @height = 1080, @title = "Andromeda")
      raise "AHHHHHHHH GLFW COULD NOT BE INITIALIZED SOMETHING IS REALLY WRONG THIS HAS NEVER HAPPENED BEFORE AAAAAAHHHHHHHHHHHH" unless LibGLFW.init
      LibGLFW.window_hint(LibGLFW::CONTEXT_VERSION_MAJOR, 4)
      LibGLFW.window_hint(LibGLFW::CONTEXT_VERSION_MINOR, 5)
      LibGLFW.window_hint(LibGLFW::OPENGL_PROFILE, LibGLFW::OPENGL_CORE_PROFILE)

      @handle = LibGLFW.create_window @width, @height, @title, LibGLFW.get_primary_monitor, nil

      make_context_current
      @cursor = {0.0, 0.0}
      @moved = @cursor

      raise "Failed to open GLFW window" if @handle.is_a?(Nil)
    end

    def make_context_current
      LibGLFW.set_current_context @handle
    end

    def key_pressed?(key_enum)
      (LibGLFW.get_key @handle, key_enum) == LibGLFW::PRESS
    end

    def mouse_moved
      @moved
    end

    def update
      LibGLFW.poll_events
      LibGLFW.swap_buffers @handle
      LibGLFW.get_cursor_pos @handle, out posX, out posY
      pos = {posX, posY}
      if (pos != @cursor)
        @moved = {(@cursor[0] - pos[0]), (@cursor[1] - pos[1])}
        @cursor = pos
      else
        @moved = {0.0, 0.0}
      end
      # LibGLFW.set_cursor_pos @handle, 0.0, 0.0
      if (LibGLFW.window_should_close @handle) != LibGL::E_TRUE
        return true
      end
      return false
    end

    def to_unsafe
      @handle
    end
  end
end
