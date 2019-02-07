defmodule Protobuf.MsgDef do
  defstruct fields: %{},
            oneof_fields: %{}
  @type t :: %__MODULE__{
    fields: %{atom => Protobuf.Field.t},
    oneof_fields: %{atom => Protobuf.OneOfField.t}
  }
end
