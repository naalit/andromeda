require "./andromeda/*"

module Andromeda
  main_window = Window.new 1920, 1080
  LibGLFW.set_input_mode main_window, LibGLFW::CURSOR, LibGLFW::CURSOR_DISABLED

  OpenGL.background 1_f32, 0_f32, 0_f32

  # Initialize some triangles
  OpenGL.init

  vs = OpenGL::VertexShader.new <<-GLSL
    #version 450 core
    layout(location=0) in vec2 position;
    layout(location=1) in vec3 rayIn;
    out vec3 ray;
    void main(){
      gl_Position = vec4(position, 0.0, 1.0);
      ray = rayIn;
    }
    GLSL
  fs = OpenGL::FragmentShader.new File.read "src/andromeda/main.frag"

  program = OpenGL::Program.new vs, fs
  # OpenGL.post_init program
  program.link.use

  LibGL.viewport 0, 0, 1920, 1080

  while main_window.update && !main_window.key_pressed? LibGLFW::KEY_ESCAPE
    OpenGL.clear
    OpenGL.update_rays main_window
    OpenGL.draw
  end
end
