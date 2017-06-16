# Simple linear algebra library
module Andromeda::Linear
  class Vec3
    def initialize(@x : Float64, @y : Float64, @z : Float64)
    end

    def [](i : Int32)
      case i
      when 0
        return x
      when 1
        return y
      when 2
        return z
      else
        raise IndexError.new("Uhh, it's a Vec3, not a Vec" + i.to_s)
      end
    end

    def []=(i : Int32, v : Float64)
      case i
      when 0
        x = v
      when 1
        y = v
      when 2
        z = v
      else
        raise IndexError.new("Uhh, it's a Vec3, not a Vec" + i.to_s)
      end
    end

    def x
      @x
    end

    def x=(newX : Float64)
      @x = newX
    end

    def y
      @y
    end

    def y=(newY : Float64)
      @y = newY
    end

    def z
      @z
    end

    def z=(newZ : Float64)
      @z = newZ
    end

    def +(other : self)
      Vec3.new x + other.x, y + other.y, z + other.z
    end

    def -(other : self)
      Vec3.new x - other.x, y - other.y, z - other.z
    end

    def dot(other : self)
      x*other.x + y*other.y + z*other.z
    end

    def cross(other : self)
      Vec3.new y*other.z - z*other.y, z*other.x - x*other.z, x*other.y - y*other.x
    end

    def +(other : Number) # Vector + scalar
      Vec3.new x + other, y + other, z + other
    end

    def -(other : Number)
      Vec3.new x - other, y - other, z - other
    end

    def *(other : Number)
      Vec3.new x*other, y*other, z*other
    end

    def /(other : Number)
      Vec3.new x/other, y/other, z/other
    end

    def len
      (Math.sqrt ((x * y) + (y * y) + (z * z))) # Look, Lisp!
    end

    def normalize
      self / len
    end

    def rotateZ(angle)
      Vec3.new(
        x * Math.cos(angle) - y * Math.sin(angle),
        x * Math.sin(angle) + y * Math.cos(angle),
        z
      )
    end

    def rotateY(angle)
      Vec3.new(
        x * Math.cos(angle) + z * Math.sin(angle),
        y,
        -x * Math.sin(angle) + z * Math.cos(angle)
      )
    end

    def rotateX(angle)
      Vec3.new(
        x,
        y * Math.cos(angle) - z * Math.sin(angle),
        y * Math.sin(angle) + z * Math.cos(angle)
      )
    end
  end
end

# To see how far the Lisping can go
# (def stuff
#  (2)
# end) # Works
# (def moreStuff(x, y, z)
#  (x + (y + z))
# end)                               # That too
# (puts (moreStuff 1, 2, (3*stuff))) # Wow. That's some Lisp.
# (puts 2)                           # This works too, just like Lisp!
# (puts [2, 4, 3])                   # Clojure-like Arrays
