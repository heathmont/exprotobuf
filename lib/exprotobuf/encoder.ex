defmodule Protobuf.Encoder do
  require Protobuf.Utils, as: Utils
  alias Protobuf.Field
  alias Protobuf.MsgDef
  alias Protobuf.OneOfField

  def encode(%{} = msg, defs) do
    fixed_defs =
      for {{type, mod}, fields} <- defs, into: [] do
        case type do
          :msg ->
            {{:msg, mod},
             Enum.map(fields, fn field ->
               case field do
                 %OneOfField{} -> field |> Utils.convert_to_record(OneOfField)
                 %Field{} -> field |> Utils.convert_to_record(Field)
               end
             end)}

          type when type in [:enum, :extensions, :service, :group] ->
            {{type, mod}, fields}
        end
      end

    msg
    |> Utils.walk(fn val, field_def, %{} = msg_defs, original_module ->
      val
      |> Protobuf.PreEncodable.pre_encode(original_module)
      |> wrap_scalars_walker(field_def, msg_defs)
      |> fix_undefined_walker
      |> convert_to_record_walker
    end)
    |> :gpb.encode_msg(fixed_defs)
  end

  defp wrap_scalars_walker(val, %Field{} = field_def, %{} = msg_defs)
       when Utils.is_scalar(val) do
    field_def
    |> case do
      %Field{type: scalar} when is_atom(scalar) ->
        val

      %Field{type: {:enum, module}} when is_atom(module) ->
        val

      %Field{type: {:msg, module}} when is_atom(module) ->
        if Utils.is_standard_scalar_wrapper(module) do
          module.new
          |> Map.put(:value, val)
        else
          maybe_wrap_enum(val, module, msg_defs)
        end
    end
  end

  defp wrap_scalars_walker(val, _, %{}) do
    val
  end

  defp maybe_wrap_enum(val, module, %{} = msg_defs) when Utils.is_scalar(val) do
    msg_defs
    |> Map.get(module)
    |> case do
      %MsgDef{
        fields: %{value: %Field{type: {:enum, enum_module}}} = fields,
        oneof_fields: %{} = oneof_fields
      }
      when map_size(fields) == 1 and map_size(oneof_fields) == 0 ->
        module
        |> Utils.is_enum_wrapper(enum_module)
        |> case do
          true ->
            module.new
            |> Map.put(:value, val)

          false ->
            val
        end

      %MsgDef{} ->
        val
    end
  end

  defp fix_undefined_walker(nil), do: :undefined
  defp fix_undefined_walker(val), do: val

  defp convert_to_record_walker(%data_type{} = data), do: Utils.convert_to_record(data, data_type)
  defp convert_to_record_walker(val), do: val
end
