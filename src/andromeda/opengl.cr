require "./lib_gl"
require "./linear"

include Andromeda::Linear

# Wrapper around lib_gl
module Andromeda::OpenGL
  extend self

  @@rays = [] of Float32
  @@vao = 0_u32
  @@octree = Buffer(UInt32).new
  @@view = Vec3.new 0.0, 0.0, 1.0
  @@buffer2 = Buffer(Float32).new
  @@pos = Vec3.new 0.0, 0.0, 0.0

  def clear
    LibGL.clear LibGL::E_COLOR_BUFFER_BIT
  end

  def background(r, g, b)
    LibGL.clear_color r, g, b, 1.0
  end

  class VertexShader
    def initialize(@source : String)
      @handle = LibGL.create_shader LibGL::E_VERTEX_SHADER
      a = @source.size
      b = @source.to_unsafe
      LibGL.shader_source @handle, 1, pointerof(b), nil
      LibGL.compile_shader @handle
      LibGL.get_shaderiv(@handle, LibGL::E_COMPILE_STATUS, out compiled?)
      if compiled? == LibGL::E_FALSE
        length = 512
        LibGL.get_shader_info_log @handle, length, nil, out buffer
        raise "Compilation of vertex shader failed: #{buffer}"
      end
    end

    def handle
      @handle
    end

    def finalize
      LibGL.delete_shader @handle
    end
  end

  class FragmentShader
    def initialize(@source : String)
      @handle = LibGL.create_shader LibGL::E_FRAGMENT_SHADER
      a = @source.size
      b = @source.to_unsafe
      LibGL.shader_source @handle, 1, pointerof(b), nil
      LibGL.compile_shader @handle
      LibGL.get_shaderiv(@handle, LibGL::E_COMPILE_STATUS, out compiled?)
      if compiled? == LibGL::E_FALSE
        length = 512
        log = String.new(length) { |buffer|
          LibGL.get_shader_info_log @handle, length, nil, buffer
          {length, length}
        }
        raise "Compilation of fragment shader failed: #{log}"
      end
    end

    def handle
      @handle
    end

    def finalize
      LibGL.delete_shader @handle
    end
  end

  class Program
    getter :handle

    @vertex : VertexShader
    @fragment : FragmentShader

    #  def initialize
    #    @handle = LibGL.create_program
    #    @vertex = VertexShader.new <<-GLSL
    #      #version 450 core
    #
    #        layout(location=0)in vec2 vert;
    #        layout(location=1)in vec3 rayIn;
    #        out vec3 ray;
    #
    #        void main () {
    #          ray = rayIn;
    #          gl_Position = vert;
    #        }
    #      GLSL
    #      @fragment = FragmentShader.new (File.read "src/andromeda/main.glsl")
    #      attach @vertex
    #      attach @fragment
    #    end

    def initialize(@vertex, @fragment)
      @handle = LibGL.create_program
      attach @vertex
      attach @fragment
    end

    def attach(shader : VertexShader | FragmentShader)
      LibGL.attach_shader @handle, shader.handle
      self
    end

    def link
      LibGL.link_program @handle

      LibGL.get_programiv @handle, LibGL::E_LINK_STATUS, out result
      length = 512
      LibGL.get_program_info_log @handle, length, nil, out info_log
      raise "Error linking shader program: #{info_log}" unless result == LibGL::E_TRUE

      self
    end

    def use
      LibGL.use_program @handle
      self
    end

    def finalize
      LibGL.use_program 0 # Unbind

      LibGL.detach_shader @handle, @vertex.handle # Detach shaders
      LibGL.detach_shader @handle, @fragment.handle

      LibGL.delete_program @handle # Delete program. Shaders delete themselves in their finalize methods
    end
  end

  class Buffer(T)
    @handle : UInt32
    @target = LibGL::E_ARRAY_BUFFER

    def initialize
      LibGL.gen_buffers 1, out handle
      @handle = handle
    end

    def initialize(datas)
      LibGL.gen_buffers 1, out handle
      @handle = handle
      bind
      data datas, LibGL::E_STATIC_DRAW
    end

    def bind
      LibGL.bind_buffer @target, @handle
    end

    def data(datas : Array(T), dynamicness)
      LibGL.buffer_data @target, sizeof(T) * datas.size, datas, dynamicness
    end

    def target=(new_target)
      @target = new_target
    end
  end

  def get_rays(look)
    pos = Vec3.new 0.0, 0.0, 0.0
    screen = pos + look
    screen00 = Vec3.new screen.x - 0.5, screen.y - 0.5, screen.z
    screen01 = Vec3.new screen.x - 0.5, screen.y + 0.5, screen.z # So we don't have to do pos+1 over and over
    screen10 = Vec3.new screen.x + 0.5, screen.y - 0.5, screen.z
    screen11 = Vec3.new screen.x + 0.5, screen.y + 0.5, screen.z
    v00 = screen00 - pos
    v01 = screen01 - pos
    v10 = screen10 - pos
    v11 = screen11 - pos
    dirs = [
      v01.x.to_f32, v01.y.to_f32, v01.z.to_f32, # A dir vec3 for each vertex (4 vertexes)
      v11.x.to_f32, v11.y.to_f32, v11.z.to_f32,
      v00.x.to_f32, v00.y.to_f32, v00.z.to_f32,
      v10.x.to_f32, v10.y.to_f32, v10.z.to_f32,
    ]
    dirs
  end

  CHILD0  = 2_u32 ** (31 - 0) # Childmask flags
  CHILD1  = 2_u32 ** (31 - 1)
  CHILD2  = 2_u32 ** (31 - 2)
  CHILD3  = 2_u32 ** (31 - 3)
  CHILD4  = 2_u32 ** (31 - 4)
  CHILD5  = 2_u32 ** (31 - 5)
  CHILD6  = 2_u32 ** (31 - 6)
  CHILD7  = 2_u32 ** (31 - 7)
  LCHILD0 = 2_u32 ** (31 - 8) # Leafmask flags
  LCHILD1 = 2_u32 ** (31 - 9)
  LCHILD2 = 2_u32 ** (31 - 10)
  LCHILD3 = 2_u32 ** (31 - 11)
  LCHILD4 = 2_u32 ** (31 - 12)
  LCHILD5 = 2_u32 ** (31 - 13)
  LCHILD6 = 2_u32 ** (31 - 14)
  LCHILD7 = 2_u32 ** (31 - 15)

  def init
    points = [
      -1_f32, 1_f32,
      1_f32, 1_f32,
      -1_f32, -1_f32,
      1_f32, -1_f32,
    ]

    @@rays = get_rays @@view

    LibGL.gen_vertex_arrays 1, out vao
    @@vao = vao
    LibGL.bind_vertex_array @@vao
    LibGL.enable_vertex_attrib_array 0
    buffer = Buffer(Float32).new points

    LibGL.vertex_attrib_pointer 0, 2, LibGL::E_FLOAT, LibGL::E_FALSE, 0, nil

    @@buffer2 = Buffer(Float32).new @@rays
    LibGL.vertex_attrib_pointer 1, 3, LibGL::E_FLOAT, LibGL::E_FALSE, 0, nil
    LibGL.enable_vertex_attrib_array 1

    scene = [
      1_u32 | CHILD4, # Root node
      2_u32 | CHILD2 | CHILD3 | LCHILD3,
      0_u32 | CHILD1 | CHILD2 | LCHILD1 | LCHILD2,
    ]

    # scene = [0_u32 | CHILD1 | LCHILD1 | CHILD2 | LCHILD2 | CHILD3 | LCHILD3 | CHILD4 | LCHILD4 | CHILD5 | LCHILD5 | CHILD6 | LCHILD6 | CHILD7 | LCHILD7 | CHILD0 | LCHILD0]

    @@octree = Buffer(UInt32).new
    @@octree.target = LibGL::E_SHADER_STORAGE_BUFFER
    @@octree.bind
    @@octree.data scene, LibGL::E_STATIC_DRAW
    LibGL.bind_buffer_base LibGL::E_SHADER_STORAGE_BUFFER, 0, @@octree.@handle
  end

  def post_init
    LibGL.uniform3f(1, @@pos.x, @@pos.y, @@pos.z)
    LibGL.uniform3f(2, -10_f32, -10_f32, -10_f32)
    LibGL.uniform3f(3, 10_f32, 10_f32, 10_f32)
  end

  def draw
    LibGL.draw_arrays LibGL::E_TRIANGLE_STRIP, 0, 4
    LibGL.finish
  end

  def update_rays(window)
    moved = window.mouse_moved
    if moved != {0.0, 0.0}
      @@view = @@view.rotateX(
        (moved[0] / (1920/2)) * (2 * Math::PI)
      )
      @@view = @@view.rotateY(
        (moved[1] / (1080/2)) * (Math::PI)
      )
      @@rays = get_rays @@view
      @@buffer2.data @@rays, LibGL::E_DYNAMIC_DRAW
    end
    if (window.key_pressed? LibGLFW::KEY_S)
      @@pos = @@pos - (@@view * -0.5)
    end

    if (window.key_pressed? LibGLFW::KEY_W)
      @@pos = @@pos - (@@view * 0.5)
    end

    LibGL.uniform3f(1, @@pos.x, @@pos.y, @@pos.z)
  end
end
