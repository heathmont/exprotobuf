defmodule Protobuf.ValidatorTest do
  use Protobuf.Case
  require Protobuf.IntegerTypes, as: IntegerTypes

  defmodule Schema3 do
    use Protobuf, """
    syntax = "proto3";
    message Proto3 {
      double double = 1;
      float float = 2;
      int32 int32 = 3;
      int64 int64 = 4;
      uint32 uint32 = 5;
      uint64 uint64 = 6;
      sint32 sint32 = 7;
      sint64 sint64 = 8;
      fixed32 fixed32 = 9;
      fixed64 fixed64 = 10;
      sfixed32 sfixed32 = 11;
      sfixed64 sfixed64 = 12;
      bool bool = 13;
      string string = 14;
      bytes bytes = 15;

      Enum enum = 16;
      Msg msg = 17;

      oneof either {
        string either_string = 18;
        Msg either_msg = 19;
      }

      repeated double repeated_double = 20;
      repeated float repeated_float = 21;
      repeated int32 repeated_int32 = 22;
      repeated int64 repeated_int64 = 23;
      repeated uint32 repeated_uint32 = 24;
      repeated uint64 repeated_uint64 = 25;
      repeated sint32 repeated_sint32 = 26;
      repeated sint64 repeated_sint64 = 27;
      repeated fixed32 repeated_fixed32 = 28;
      repeated fixed64 repeated_fixed64 = 29;
      repeated sfixed32 repeated_sfixed32 = 30;
      repeated sfixed64 repeated_sfixed64 = 31;
      repeated bool repeated_bool = 32;
      repeated string repeated_string = 33;
      repeated bytes repeated_bytes = 34;

      repeated Enum repeated_enum = 35;
      repeated Msg repeated_msg = 36;

      map<string, string> map = 37;

      enum Enum {
        START = 0;
        STOP  = 1;
      }

      message Msg {
        string key = 1;
        string value = 2;
      }
    }
    """
  end

  alias Schema3.Proto3

  setup do
    double = -0.5
    float = -0.5
    int32 = IntegerTypes.max_int32()
    int64 = IntegerTypes.max_int64()
    uint32 = IntegerTypes.max_uint32()
    uint64 = IntegerTypes.max_uint64()
    sint32 = IntegerTypes.max_int32()
    sint64 = IntegerTypes.max_int64()
    fixed32 = IntegerTypes.max_uint32()
    fixed64 = IntegerTypes.max_uint64()
    sfixed32 = IntegerTypes.max_int32()
    sfixed64 = IntegerTypes.max_int64()
    bool = true
    string = "hello"
    bytes = <<255, 255, 255>>
    enum = :START
    map = %{"hello" => "world"}

    msg = %Proto3.Msg{
      key: "foo",
      value: "bar"
    }

    %{
      proto3: %Proto3{
        double: double,
        float: float,
        int32: int32,
        int64: int64,
        uint32: uint32,
        uint64: uint64,
        sint32: sint32,
        sint64: sint64,
        fixed32: fixed32,
        fixed64: fixed64,
        sfixed32: sfixed32,
        sfixed64: sfixed64,
        bool: bool,
        string: string,
        bytes: bytes,
        enum: enum,
        msg: msg,
        either: {:either_msg, msg},
        repeated_double: [double],
        repeated_float: [float],
        repeated_int32: [int32],
        repeated_int64: [int64],
        repeated_uint32: [uint32],
        repeated_uint64: [uint64],
        repeated_sint32: [sint32],
        repeated_sint64: [sint64],
        repeated_fixed32: [fixed32],
        repeated_fixed64: [fixed64],
        repeated_sfixed32: [sfixed32],
        repeated_sfixed64: [sfixed64],
        repeated_bool: [bool],
        repeated_string: [string],
        repeated_bytes: [bytes],
        repeated_enum: [enum],
        repeated_msg: [msg],
        map: map
      }
    }
  end

  test "proto3 success", %{proto3: %Proto3{} = proto3} do
    import Proto3
    assert :ok = proto3 |> validate
    assert :ok = proto3 |> validate!
  end

  test "proto3 validate! raise", %{proto3: %Proto3{} = proto3} do
    import Proto3

    assert_raise RuntimeError,
                 ~r/^Elixir.Protobuf.ValidatorTest.Schema3.Proto3.t has invalid value 123 of field.+$/,
                 fn ->
                   %Proto3{proto3 | float: 123}
                   |> validate!
                 end
  end

  test "proto3 double + float", %{
    proto3: %Proto3{repeated_double: repeated_double, repeated_float: repeated_float} = proto3
  } do
    import Proto3
    other_erlang_type = 123

    [
      other_erlang_type,
      nil,
      [other_erlang_type | repeated_double],
      [nil | repeated_double],
      [other_erlang_type | repeated_float],
      [nil | repeated_float]
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | double: val} |> validate
      assert {:error, _} = %Proto3{proto3 | float: val} |> validate
      assert {:error, _} = %Proto3{proto3 | repeated_double: val} |> validate
      assert {:error, _} = %Proto3{proto3 | repeated_float: val} |> validate

      assert {:error, _} =
               %Proto3{proto3 | repeated_double: val} |> validate(allow_scalar_nil: true)

      assert {:error, _} =
               %Proto3{proto3 | repeated_float: val} |> validate(allow_scalar_nil: true)
    end)

    assert :ok = %Proto3{proto3 | double: nil} |> validate(allow_scalar_nil: true)
    assert :ok = %Proto3{proto3 | float: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 int32 + sint32 + sfixed32", %{
    proto3:
      %Proto3{
        repeated_int32: repeated_int32,
        repeated_sint32: repeated_sint32,
        repeated_sfixed32: repeated_sfixed32
      } = proto3
  } do
    import Proto3
    other_erlang_type = 1.23
    pos_overflow = IntegerTypes.max_int32() + 1
    neg_overflow = IntegerTypes.min_int32() - 1

    [
      other_erlang_type,
      pos_overflow,
      neg_overflow,
      nil,
      [other_erlang_type | repeated_int32],
      [pos_overflow | repeated_int32],
      [neg_overflow | repeated_int32],
      [nil | repeated_int32],
      [other_erlang_type | repeated_sint32],
      [pos_overflow | repeated_sint32],
      [neg_overflow | repeated_sint32],
      [nil | repeated_sint32],
      [other_erlang_type | repeated_sfixed32],
      [pos_overflow | repeated_sfixed32],
      [neg_overflow | repeated_sfixed32],
      [nil | repeated_sfixed32]
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | int32: val} |> validate
      assert {:error, _} = %Proto3{proto3 | sint32: val} |> validate
      assert {:error, _} = %Proto3{proto3 | sfixed32: val} |> validate

      assert {:error, _} = %Proto3{proto3 | repeated_int32: val} |> validate
      assert {:error, _} = %Proto3{proto3 | repeated_sint32: val} |> validate
      assert {:error, _} = %Proto3{proto3 | repeated_sfixed32: val} |> validate

      assert {:error, _} =
               %Proto3{proto3 | repeated_int32: val} |> validate(allow_scalar_nil: true)

      assert {:error, _} =
               %Proto3{proto3 | repeated_sint32: val} |> validate(allow_scalar_nil: true)

      assert {:error, _} =
               %Proto3{proto3 | repeated_sfixed32: val} |> validate(allow_scalar_nil: true)
    end)

    assert :ok = %Proto3{proto3 | int32: nil} |> validate(allow_scalar_nil: true)
    assert :ok = %Proto3{proto3 | sint32: nil} |> validate(allow_scalar_nil: true)
    assert :ok = %Proto3{proto3 | sfixed32: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 int64 + sint64 + sfixed64", %{
    proto3:
      %Proto3{
        repeated_int64: repeated_int64,
        repeated_sint64: repeated_sint64,
        repeated_sfixed64: repeated_sfixed64
      } = proto3
  } do
    import Proto3
    other_erlang_type = 1.23
    pos_overflow = IntegerTypes.max_int64() + 1
    neg_overflow = IntegerTypes.min_int64() - 1

    [
      other_erlang_type,
      pos_overflow,
      neg_overflow,
      nil,
      [other_erlang_type | repeated_int64],
      [pos_overflow | repeated_int64],
      [neg_overflow | repeated_int64],
      [nil | repeated_int64],
      [other_erlang_type | repeated_sint64],
      [pos_overflow | repeated_sint64],
      [neg_overflow | repeated_sint64],
      [nil | repeated_sint64],
      [other_erlang_type | repeated_sfixed64],
      [pos_overflow | repeated_sfixed64],
      [neg_overflow | repeated_sfixed64],
      [nil | repeated_sfixed64]
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | int64: val} |> validate
      assert {:error, _} = %Proto3{proto3 | sint64: val} |> validate
      assert {:error, _} = %Proto3{proto3 | sfixed64: val} |> validate

      assert {:error, _} = %Proto3{proto3 | repeated_int64: val} |> validate
      assert {:error, _} = %Proto3{proto3 | repeated_sint64: val} |> validate
      assert {:error, _} = %Proto3{proto3 | repeated_sfixed64: val} |> validate

      assert {:error, _} =
               %Proto3{proto3 | repeated_int64: val} |> validate(allow_scalar_nil: true)

      assert {:error, _} =
               %Proto3{proto3 | repeated_sint64: val} |> validate(allow_scalar_nil: true)

      assert {:error, _} =
               %Proto3{proto3 | repeated_sfixed64: val} |> validate(allow_scalar_nil: true)
    end)

    assert :ok = %Proto3{proto3 | int64: nil} |> validate(allow_scalar_nil: true)
    assert :ok = %Proto3{proto3 | sint64: nil} |> validate(allow_scalar_nil: true)
    assert :ok = %Proto3{proto3 | sfixed64: nil} |> validate(allow_scalar_nil: true)
  end

  #
  # TODO : all tests for :repeated fields
  #

  test "proto3 uint32 + fixed32", %{proto3: %Proto3{} = proto3} do
    import Proto3
    other_erlang_type = 1.23
    pos_overflow = IntegerTypes.max_uint32() + 1
    neg_overflow = IntegerTypes.min_uint32() - 1

    [
      other_erlang_type,
      pos_overflow,
      neg_overflow,
      nil
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | uint32: val} |> validate
      assert {:error, _} = %Proto3{proto3 | fixed32: val} |> validate
    end)

    assert :ok = %Proto3{proto3 | uint32: nil} |> validate(allow_scalar_nil: true)
    assert :ok = %Proto3{proto3 | fixed32: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 uint64 + fixed64", %{proto3: %Proto3{} = proto3} do
    import Proto3
    other_erlang_type = 1.23
    pos_overflow = IntegerTypes.max_uint64() + 1
    neg_overflow = IntegerTypes.min_uint64() - 1

    [
      other_erlang_type,
      pos_overflow,
      neg_overflow,
      nil
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | uint64: val} |> validate
      assert {:error, _} = %Proto3{proto3 | fixed64: val} |> validate
    end)

    assert :ok = %Proto3{proto3 | uint64: nil} |> validate(allow_scalar_nil: true)
    assert :ok = %Proto3{proto3 | fixed64: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 bool", %{proto3: %Proto3{} = proto3} do
    import Proto3
    other_erlang_type = 123

    [
      other_erlang_type,
      nil
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | bool: val} |> validate
    end)

    assert :ok = %Proto3{proto3 | bool: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 string", %{proto3: %Proto3{} = proto3} do
    import Proto3
    other_erlang_type = 123
    invalid_string = <<255, 255, 255>>

    [
      other_erlang_type,
      invalid_string,
      nil
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | string: val} |> validate
    end)

    assert :ok = %Proto3{proto3 | string: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 bytes", %{proto3: %Proto3{} = proto3} do
    import Proto3
    other_erlang_type = 123

    [
      other_erlang_type,
      nil
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | bytes: val} |> validate
    end)

    assert :ok = %Proto3{proto3 | bytes: "hello"} |> validate
    assert :ok = %Proto3{proto3 | bytes: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 enum", %{proto3: %Proto3{} = proto3} do
    import Proto3
    other_erlang_type = 123
    invalid_enum_value = :HELLO

    [
      other_erlang_type,
      invalid_enum_value,
      nil
    ]
    |> Enum.each(fn val ->
      assert {:error, _} = %Proto3{proto3 | enum: val} |> validate
    end)

    pos_overflow = IntegerTypes.max_int32() + 1
    neg_overflow = IntegerTypes.min_int32() - 1

    assert {:error, _} =
             %Proto3{proto3 | enum: pos_overflow} |> validate(allow_enum_integer: true)

    assert {:error, _} =
             %Proto3{proto3 | enum: neg_overflow} |> validate(allow_enum_integer: true)

    assert :ok = %Proto3{proto3 | enum: 0} |> validate(allow_enum_integer: true)
    assert :ok = %Proto3{proto3 | enum: 1} |> validate(allow_enum_integer: true)
    assert :ok = %Proto3{proto3 | enum: 100} |> validate(allow_enum_integer: true)
    assert :ok = %Proto3{proto3 | enum: nil} |> validate(allow_scalar_nil: true)
  end

  test "proto3 msg", %{proto3: %Proto3{msg: %Proto3.Msg{} = msg} = proto3} do
    import Proto3
    assert :ok = %Proto3{proto3 | msg: nil} |> validate
    assert {:error, _} = %Proto3{proto3 | msg: %URI{}} |> validate
    assert {:error, _} = %Proto3{proto3 | msg: %Proto3.Msg{msg | key: 123}} |> validate
    assert {:error, _} = %Proto3{proto3 | msg: %Proto3.Msg{msg | key: nil}} |> validate

    assert :ok =
             %Proto3{proto3 | msg: %Proto3.Msg{msg | key: nil}}
             |> validate(allow_scalar_nil: true)
  end

  test "proto3 oneof", %{proto3: %Proto3{either: {:either_msg, %Proto3.Msg{} = msg}} = proto3} do
    import Proto3
    assert :ok = %Proto3{proto3 | either: nil} |> validate
    assert :ok = %Proto3{proto3 | either: {:either_string, "hello"}} |> validate
    assert {:error, _} = %Proto3{proto3 | either: {:either_string, 123}} |> validate
    assert {:error, _} = %Proto3{proto3 | either: {:either_string, nil}} |> validate

    assert {:error, _} =
             %Proto3{proto3 | either: {:either_string, nil}} |> validate(allow_scalar_nil: true)

    assert {:error, _} = %Proto3{proto3 | either: {:either_msg, 123}} |> validate
    assert {:error, _} = %Proto3{proto3 | either: {:either_msg, nil}} |> validate
    assert {:error, _} = %Proto3{proto3 | either: {:hello, "world"}} |> validate

    assert {:error, _} =
             %Proto3{proto3 | either: {:either_msg, %Proto3.Msg{msg | key: 123}}} |> validate
  end

  test "proto3 map", %{proto3: %Proto3{map: %{} = map} = proto3} do
    import Proto3
    assert {:error, _} = %Proto3{proto3 | map: Map.put(map, "foo", 123)} |> validate
    assert {:error, _} = %Proto3{proto3 | map: Map.put(map, 123, "foo")} |> validate
    assert :ok = %Proto3{proto3 | map: Map.put(map, "foo", "bar")} |> validate
    assert {:error, _} = %Proto3{proto3 | map: [{"foo", 123}]} |> validate
    assert {:error, _} = %Proto3{proto3 | map: [{123, "bar"}]} |> validate
    assert :ok = %Proto3{proto3 | map: [{"foo", "bar"}]} |> validate
    assert {:error, _} = %Proto3{proto3 | map: ["foo"]} |> validate
    assert {:error, _} = %Proto3{proto3 | map: "foo"} |> validate
  end

  #
  # TODO : proto2 tests
  #
end
