defprotocol Protobuf.PreEncodable do
  @moduledoc """
  Defines the contract for custom pre-encode hooks
  """
  @fallback_to_any true

  @doc """
  Function is applied to term of given type before protobuf encode,
  second argument is original module name of message from protobuf schema
  """
  def pre_encode(term, original_module)
end

defimpl Protobuf.PreEncodable, for: Any do
  def pre_encode(term, _), do: term
end
