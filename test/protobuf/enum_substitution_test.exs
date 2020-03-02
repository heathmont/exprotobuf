defmodule Protobuf.EnumSubstitution.Test do
  use Protobuf.Case
  use ExUnitProperties

  defmodule Proto do
    use Protobuf, from: Path.expand("../proto/enum_substitution.proto", __DIR__)
  end

  alias Proto.MsgH0
  alias Proto.MsgW0
  alias Proto.MsgH1
  alias Proto.MsgW1
  alias Proto.MsgH2
  alias Proto.MsgW2

  describe "Hello and World are binary compatible:" do
    property "encoded binaries equality" do
      require Proto.Hello.Hello, as: Hello
      require Proto.World.World, as: World
      enum_atoms = (Hello.atoms() ++ World.atoms()) |> Enum.uniq()

      check all(
              s <- string(:printable),
              i <- integer(),
              e <- one_of(enum_atoms)
            ) do
        [
          {
            %MsgH0{int64: i, string: s, hello: e},
            %MsgW0{int64: i, string: s, world: e}
          },
          {
            %MsgH1{int64: i, string: s, hello: e},
            %MsgW1{int64: i, string: s, world: e}
          },
          {
            %MsgH2{int64: i, string: s, hello: e},
            %MsgW2{int64: i, string: s, world: e}
          }
        ]
        |> Enum.each(fn {%ml{} = left, %mr{} = right} ->
          assert ml.encode(left) == mr.encode(right)
        end)
      end
    end
  end
end
