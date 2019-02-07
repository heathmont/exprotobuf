defprotocol Protobuf.PreEncodable do
  @moduledoc """
  Defines the contract for custom pre-encode hooks
  """
  @fallback_to_any true

  @doc """
  Function is applied to term of given type before protobuf encode
  """
  def pre_encode(term)
end

defimpl Protobuf.PreEncodable, for: Any do
  def pre_encode(term), do: term
end
